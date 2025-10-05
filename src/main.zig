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

    // Setup interrupts.
    log.info("Setting up interrupts...", .{});
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

        hugin.intr.init(dist_reg, redist_reg);
    }

    // Enable PL011 interrupt.
    log.info("Enabling PL011 interrupt...", .{});
    {
        const pl011_node = try dtb.searchNode(
            .{ .compat = "arm,pl011" },
            null,
        ) orelse {
            return error.SearchPl011Node;
        };
        const intr_prop = try dtb.getProp(pl011_node, "interrupts") orelse {
            return error.NoInterruptsProperty;
        };
        const prop_data = intr_prop.slice();

        const valid =
            hugin.bits.fromBigEndian(prop_data[0]) == 0 // interrupt kind: SPI
            and hugin.bits.fromBigEndian(prop_data[2]) == 4 // trigger type: level
        ;
        const inum = if (valid) hugin.bits.fromBigEndian(prop_data[1]) else {
            return error.InvalidPl011IntrProp;
        };

        try hugin.serial.enableIntr(@intCast(inum));
    }

    // Enable generic timer.
    log.info("Initializing a generic timer globally...", .{});
    {
        try hugin.drivers.timer.initGlobal(dtb);
    }

    // Setup virtio-blk device.
    log.info("Setting up virtio-blk device...", .{});
    const fat = blk: {
        var vblk = try setupVirtioBlk(dtb) orelse {
            log.warn("No virtio-blk device found.", .{});
            return error.NoVirtioBlkDevice;
        };
        log.info("Found the target MMIO virtio-blk device @ 0x{X}", .{vblk.vreg.base});

        // Init filesystem.
        const fat32 = try hugin.Fat32.from(&vblk, hugin.mem.page_allocator);

        // Read Hugin kernel image.
        const hugin_elf = (try fat32.lookup("HUGIN")).?;
        log.debug("Found Hugin kernel ELF: {d} bytes", .{hugin_elf.size});

        const buf = try hugin.mem.general_allocator.alloc(u8, hugin_elf.size);
        defer hugin.mem.general_allocator.free(buf);
        const nread = try fat32.read(hugin_elf, buf, 0, hugin.mem.page_allocator);
        hugin.rtt.expectEqual(hugin_elf.size, nread);

        // Check ELF header magic.
        hugin.rtt.expect(std.mem.eql(u8, std.elf.MAGIC, buf[0..4]));
        log.debug("Hugin kernel ELF header magic is valid.", .{});

        break :blk fat32;
    };

    // Init VM.
    {
        try hugin.vm.init(fat);
        try hugin.vm.current().boot();
    }

    // EOL.
    log.err("Reached unreachable EOL.", .{});
    while (true) {
        hugin.arch.halt();
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
            log.info("       @ 0x{X:0>16} - 0x{X:0>16}", .{
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

/// Find and setup Virtio block device.
fn setupVirtioBlk(dtb: hugin.dtb.Dtb) !?hugin.drivers.VirtioBlk {
    var cur: ?hugin.dtb.Node = null;
    while (true) {
        cur = try dtb.searchNode(
            .{ .compat = "virtio,mmio" },
            cur,
        ) orelse return null;

        if (!try dtb.isNodeOperational(cur.?)) {
            continue;
        }

        const reg = try dtb.readRegProp(cur.?, 0) orelse continue;
        log.debug("Found virtio over MMIO candidate @ 0x{X}.", .{reg.addr});
        return hugin.drivers.VirtioBlk.new(
            reg.addr,
            hugin.mem.general_allocator,
            hugin.mem.page_allocator,
        ) catch continue;
    }
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
