/// Override the standard options.
pub const std_options = std.Options{
    // Logging
    .logFn = hugin.klog.log,
    .log_level = hugin.klog.log_level,
};
/// Override the panic function.
pub const panic = @import("panic.zig").panic_fn;

/// Size of kernel stack in bytes.
const stack_size = 16 * hugin.mem.size_4kib;

/// Kernel entry point.
export fn main(argc: usize, argv: [*]const [*:0]const u8) callconv(.c) usize {
    const sp = hugin.arch.getSp();
    kernelMain(argc, argv, sp) catch |err| {
        log.err("Kernel aborted with error: {t}", .{err});
        return @intFromError(err);
    };

    return 0;
}

fn kernelMain(argc: usize, argv: [*]const [*:0]const u8, sp: usize) !void {
    if (argc != 2) {
        return error.InvalidArgumentCount;
    }

    // Parse DTB.
    const arg0 = argv[0];
    const dtb_addr_str = arg0[0..std.mem.len(arg0)];
    const dtb_addr = try std.fmt.parseInt(usize, dtb_addr_str, 0);
    const dtb = try hugin.dtb.Dtb.new(dtb_addr);

    // Initialize UART.
    {
        const pl011_node = try dtb.searchNode(
            .{ .compat = "arm,pl011" },
            null,
        ) orelse {
            return error.SearchPl011Node;
        };
        if (!try dtb.isNodeOperational(pl011_node)) {
            return error.NodeNotOperational;
        }
        const pl011_reg = try dtb.readRegProp(pl011_node, 0) orelse {
            return error.NoRegProperty;
        };
        const uart = hugin.drivers.Pl011.new(pl011_reg.addr);
        hugin.serial.init(uart);
    }

    // Initial message.
    {
        log.info("", .{});
        log.info("Hugin kernel: version {s}", .{hugin.sha});
        log.info("", .{});
        log.info("Hello from EL#{d}", .{hugin.arch.getCurrentEl()});
        log.info("", .{});

        hugin.rtt.expectEqual(2, hugin.arch.getCurrentEl());
    }

    // Setup memory.
    {
        const arg1 = argv[1];
        const elf_addr_str = arg1[0..std.mem.len(arg1)];
        const elf_addr = try std.fmt.parseInt(usize, elf_addr_str, 0);
        try setupMemory(dtb, elf_addr, sp);
    }

    // Initialize paging.
    {
        const memory = try getAvailMemory(dtb);
        log.debug("Mapping IPA to PA: 0x{X} -> 0x{X} (size: 0x{X})", .{
            memory.addr,
            memory.addr,
            memory.size,
        });
        try hugin.arch.initPaging(
            memory.addr,
            memory.addr,
            memory.size,
            hugin.mem.page_allocator,
        );
    }

    // Setup interrupts.
    {
        const gic_node = try dtb.searchNode(
            .{ .compat = "arm,gic-v3" },
            null,
        ) orelse {
            return error.SearchGicNode;
        };
        const dist_reg = try dtb.readRegProp(gic_node, 0) orelse {
            return error.NoRegProperty;
        };
        const redist_reg = try dtb.readRegProp(gic_node, 1) orelse {
            return error.NoRegProperty;
        };

        hugin.arch.initInterrupts(dist_reg, redist_reg);
    }

    // Setup hypervisor configuration.
    {
        const hcr_el2 = std.mem.zeroInit(hugin.arch.regs.HcrEl2, .{
            .rw = true, // Aarch64
            .api = true, // Disable PAuth.
            .vm = true, // Enable virtualization.
            .fmo = true, // Enable FIQ routing.
            .imo = true, // Enable IRQ routing.
            .amo = true, // Enable SError routing.
        });
        hugin.arch.am.msr(.hcr_el2, hcr_el2);
    }

    // Jump to EL1h.
    {
        // Setup EL1 state.
        const spsr_el2 = std.mem.zeroInit(hugin.arch.regs.Spsr, .{
            .m_elsp = 0b0101, // EL1h
        });
        const elr_el2 = hugin.arch.regs.Elr{
            .addr = @intFromPtr(&el1Entry),
        };
        hugin.arch.am.msr(.spsr_el2, spsr_el2);
        hugin.arch.am.msr(.elr_el2, elr_el2);

        // Setup SP_EL1.
        const el1stack_sizep = 3;
        const el1stack = try hugin.mem.page_allocator.allocPages(el1stack_sizep);
        log.debug(
            "SP_EL1: 0x{X:0>16}",
            .{@intFromPtr(el1stack.ptr) + el1stack_sizep * hugin.mem.size_4kib},
        );
        hugin.arch.am.msr(.sp_el1, @bitCast(@intFromPtr(el1stack.ptr) + el1stack_sizep * hugin.mem.size_4kib));

        // Jump to EL1h.
        log.info("Switching to EL1h...", .{});
        hugin.arch.am.eret();
    }

    // EOL.
    while (true) {
        hugin.arch.halt();
    }
}

export fn el1Entry() callconv(.c) noreturn {
    el1Main() catch |err| {
        log.err("EL1 aborted with error: {t}", .{err});
        hugin.endlessHalt();
    };

    while (true) {
        asm volatile ("wfi");
    }
}

fn el1Main() !void {
    log.info("Hello from EL1!", .{});

    if (hugin.is_runtime_test) {
        hugin.terminateQemu(0);
    }
}

fn setupMemory(dtb: hugin.dtb.Dtb, elf: usize, sp: usize) !void {
    const max_num_reserveds = 16;
    var reserveds: [max_num_reserveds]hugin.mem.PhysRegion = undefined;
    var num_reserveds: usize = 0;

    // Get available memory region from DTB.
    const avail: hugin.mem.PhysRegion = blk: {
        const region = try getAvailMemory(dtb);
        log.info("Memory @ 0x{X:0>16} - 0x{X:0>16}", .{
            region.addr,
            region.addr + region.size,
        });

        break :blk region;
    };

    // Get DTB region.
    {
        log.info("DTB    @ 0x{X:0>16} - 0x{X:0>16}", .{
            dtb.address(),
            dtb.address() + dtb.getSize(),
        });

        reserveds[num_reserveds] = .{
            .addr = dtb.address(),
            .size = dtb.getSize(),
        };
        num_reserveds += 1;
    }

    // Get kernel region.
    {
        log.info("Hugin kernel image:", .{});

        const elf_ptr: [*]const u8 = @ptrFromInt(elf);
        const ehdr: *const std.elf.Elf64_Ehdr = @ptrFromInt(elf);
        const hdr = std.elf.Header.init(ehdr.*, builtin.cpu.arch.endian());

        var iter = hdr.iterateProgramHeadersBuffer(elf_ptr[0..std.math.maxInt(usize)]);
        while (try iter.next()) |phdr| {
            if (phdr.p_type != std.elf.PT_LOAD) continue;
            log.info("\t @ 0x{X:0>16} - 0x{X:0>16}", .{
                phdr.p_paddr,
                phdr.p_paddr + phdr.p_memsz,
            });

            reserveds[num_reserveds] = .{
                .addr = phdr.p_paddr,
                .size = phdr.p_memsz,
            };
            num_reserveds += 1;
        }
    }

    // Get stack.
    {
        const stack_bottom = hugin.bits.roundup(sp, hugin.mem.page_size);
        const stack_top = stack_bottom - stack_size;
        log.info("Stack  @ 0x{X:0>16} - 0x{X:0>16}", .{
            stack_top,
            stack_bottom,
        });

        reserveds[num_reserveds] = .{
            .addr = stack_top,
            .size = stack_size,
        };
        num_reserveds += 1;
    }

    hugin.rtt.expect(num_reserveds <= max_num_reserveds);

    // Init allocators.
    hugin.mem.initAllocators(
        avail,
        reserveds[0..num_reserveds],
        log.info,
    );
}

fn getAvailMemory(dtb: hugin.dtb.Dtb) !hugin.mem.PhysRegion {
    const memory_node = try dtb.searchNode(
        .{ .name = "memory" },
        null,
    ) orelse {
        return error.SearchMemoryNode;
    };
    const memory_reg = try dtb.readRegProp(memory_node, 0) orelse {
        return error.NoRegProperty;
    };

    return .{
        .addr = memory_reg.addr,
        .size = memory_reg.size,
    };
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.main);
const builtin = @import("builtin");
const hugin = @import("hugin");
