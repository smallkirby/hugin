pub const Error = error{
    NotFound,
} ||
    hugin.dtb.DtbError ||
    hugin.mem.PageAllocator.Error ||
    hugin.mmio.MmioError ||
    hugin.intr.IntrError ||
    hugin.Fat32.Error;

/// List of VMs.
var vms: SinglyLinkedList = .{};
/// Next VM ID.
var next_vmid: u32 = 0;

/// Virtual machine instance.
pub const Vm = struct {
    const Self = @This();

    /// VM ID.
    vmid: usize,
    /// Host virtual address of the memory region allocated for the VM.
    ram_vbase: Virt,
    /// Host physical address of the memory region allocated for the VM.
    ram_pbase: Phys,
    /// Size in bytes of the memory region allocated for the VM.
    ram_size: usize,
    /// List of MMIO handlers.
    devices: SinglyLinkedList,
    /// GICv3 Distributor MMIO device.
    gicdist: *mmio.gicv3.DistributorDevice,
    /// GICv3 Redistributor MMIO device.
    gicredist: *mmio.gicv3.RedistributorDevice,
    /// Kernel information.
    kernel: Kernel,
    /// List head of VMs.
    _node: SinglyLinkedList.Node = .{},

    /// Launch the VM.
    pub fn boot(self: *const Self) noreturn {
        log.info("Booting VM#{d} (entry=0x{X})", .{ self.vmid, self.kernel.entry });

        arch.am.msr(.spsr_el2, std.mem.zeroInit(arch.regs.Spsr, .{
            .m_elsp = 0b0101, // EL1h
        }));
        arch.am.msr(.elr_el2, std.mem.zeroInit(arch.regs.Elr, .{
            .addr = self.kernel.entry,
        }));

        asm volatile (
            \\mov  x0, %[arg]
            \\mov  x1, xzr
            \\mov  x2, xzr
            \\mov  x3, xzr
            \\eret
            :
            : [arg] "r" (self.kernel.argument),
        );

        unreachable;
    }

    /// Dispatch an MMIO read handler for the given address.
    pub fn mmioRead(self: *Self, addr: usize, width: mmio.Width) mmio.Register {
        var device = self.devices.first;
        while (device) |dev| : (device = dev.next) {
            const mdev: *MmioDevice = @fieldParentPtr("_node", dev);
            if (!mdev.include(addr)) continue;
            const offset = addr - mdev.base;

            return mdev.handler.read(mdev.ctx, offset, width) catch |err| {
                log.err("MMIO read error on 0x{X}: {t}", .{ addr, err });
                @panic("Abort.");
            };
        }

        log.err("No MMIO device found for address: 0x{X}", .{addr});
        @panic("Abort.");
    }

    /// Dispatch an MMIO write handler for the given address.
    pub fn mmioWrite(self: *Self, addr: usize, value: mmio.Register) void {
        var device = self.devices.first;
        while (device) |dev| : (device = dev.next) {
            const mdev: *MmioDevice = @fieldParentPtr("_node", dev);
            if (!mdev.include(addr)) continue;
            const offset = addr - mdev.base;

            return mdev.handler.write(mdev.ctx, offset, value) catch |err| {
                log.err("MMIO write error on 0x{X}: {t}", .{ addr, err });
                @panic("Abort.");
            };
        }

        log.err("No MMIO device found for address: 0x{X}", .{addr});
        @panic("Abort.");
    }
};

/// Kernel information.
pub const Kernel = struct {
    /// Guest physical address of kernel entry point.
    entry: usize,
    /// Guest physical address of DTB.
    argument: usize,
};

/// Virtual MMIO devices.
pub const MmioDevice = struct {
    /// Any context for the MMIO device.
    ctx: *anyopaque,
    /// Base guest physical address of the MMIO device.
    base: usize,
    /// MMIO region size in bytes.
    len: usize,
    /// MMIO handler.
    handler: Handler,
    /// List head of the MMIO devices.
    _node: SinglyLinkedList.Node = .{},

    /// Vtable of the MMIO devices.
    pub const Handler = struct {
        /// Read from the MMIO device.
        read: *const fn (ctx: *anyopaque, offset: usize, width: mmio.Width) MmioError!mmio.Register,
        /// Write to the MMIO device.
        write: *const fn (ctx: *anyopaque, offset: usize, value: mmio.Register) MmioError!void,
    };

    /// Check if the given address is within the MMIO device range.
    pub fn include(self: *const MmioDevice, addr: usize) bool {
        return self.base <= addr and addr < self.base + self.len;
    }
};

/// Initialize the VM subsystem.
pub fn init(fat: hugin.Fat32) Error!void {
    // Guest physical address (IPA) of available memory.
    const ipabase = 0x4000_0000; // TODO: need mechanism to sync with dts
    const ipasize = 256 * hugin.mem.mib;

    // Allocate resources for the VM.
    const pram = try palloc.allocPages(ipasize / hugin.mem.page_size);
    const vmid = blk: {
        const tmp = next_vmid;
        next_vmid += 1;
        break :blk tmp;
    };

    // Setup Stage 2 Translation.
    {
        try arch.initPaging(
            ipabase,
            @intFromPtr(pram.ptr),
            pram.len,
            hugin.mem.page_allocator,
        );
        log.debug("VM#{d}: RAM mapped: 0x{X} -> 0x{X}", .{
            vmid,
            ipabase,
            @intFromPtr(pram.ptr),
        });
    }

    // Init vGIC
    {
        try hugin.vgic.init();
    }

    // Init Generic Timer.
    {
        try hugin.drivers.timer.initLocal();
    }

    // Setup hypervisor configuration.
    {
        arch.am.msr(.vpidr_el2, arch.am.mrs(.midr_el1));
        arch.am.msr(.vmpidr_el2, arch.am.mrs(.mpidr_el1));

        const hcr_el2 = std.mem.zeroInit(arch.regs.HcrEl2, .{
            .rw = true, // Aarch64
            .api = true, // Disable PAuth.
            .vm = true, // Enable virtualization.
            .fmo = true, // Enable FIQ routing.
            .imo = true, // Enable IRQ routing.
            .amo = true, // Enable SError routing.
        });
        arch.am.msr(.hcr_el2, hcr_el2);
    }

    // Create the VM instance.
    const vm = try allocator.create(Vm);
    vm.* = Vm{
        .vmid = vmid,
        .ram_vbase = ipabase,
        .ram_pbase = @intFromPtr(pram.ptr),
        .ram_size = pram.len,
        .devices = .{},
        .kernel = undefined,
        .gicdist = undefined,
        .gicredist = undefined,
    };
    vms.prepend(&vm._node);

    // Load a guest kernel image and DTB.
    {
        const kernel = try fat.lookup("IMAGE") orelse return Error.NotFound;
        const dtb = try fat.lookup("DTB") orelse return Error.NotFound;
        const kernel_offset = bits.roundup(dtb.size, hugin.mem.size_2mib);

        rtt.expectEqual(dtb.size, try fat.read(
            dtb,
            pram[0 .. 0 + dtb.size],
            0,
            palloc,
        ));
        rtt.expectEqual(kernel.size, try fat.read(
            kernel,
            pram[kernel_offset .. kernel_offset + kernel.size],
            0,
            palloc,
        ));

        const khdr: *KernelHeader = @ptrCast(@alignCast(&pram[kernel_offset]));
        if (khdr.magic != KernelHeader.valid_magic) {
            log.err("Invalid kernel image magic: 0x{X:0>8}", .{khdr.magic});
            return Error.NotFound;
        }
        const text_offset = if (khdr.image_size != 0) khdr.text_offset else 0x80000;

        vm.kernel = Kernel{
            .entry = ipabase + kernel_offset + text_offset,
            .argument = ipabase,
        };

        log.debug("Guest Kernel Info (IPA):", .{});
        log.debug("    DTB         : 0x{X} - 0x{X}", .{
            vm.kernel.argument,
            vm.kernel.argument + dtb.size,
        });
        log.debug("    Entry       : 0x{X}", .{vm.kernel.entry});
        log.debug("    Text Offset : 0x{X}", .{text_offset});
        log.debug("    Image Size  : {d} bytes", .{khdr.image_size});
        log.debug("    Flags       : 0x{X:0>16}", .{khdr.flags});
    }

    // Add MMIO devices.
    {
        const pl011 = try mmio.pl001.Device.new(
            allocator,
            0x0900_0000, // TODO: need mechanism to sync with dts
            0x1000,
        );
        vm.devices.prepend(&pl011.interface._node);
    }
    {
        const gicd = try mmio.gicv3.DistributorDevice.new(
            allocator,
            0x0800_0000, // TODO: need mechanism to sync with dts
            0x10000,
        );
        vm.devices.prepend(&gicd.interface._node);
        vm.gicdist = gicd;

        const gicr = try mmio.gicv3.RedistributorDevice.new(
            allocator,
            0x080A_0000, // TODO: need mechanism to sync with dts
            0x20000,
        );
        vm.devices.prepend(&gicr.interface._node);
        vm.gicredist = gicr;
    }
}

/// Get the current VM instance.
pub fn current() *Vm {
    return @fieldParentPtr("_node", vms.first.?);
}

/// Kernel header of Aarch64 Linux kernel.
///
/// See https://www.kernel.org/doc/Documentation/arm64/booting.txt
const KernelHeader = extern struct {
    const valid_magic = 0x644d5241; // "ARM\x64"

    /// Executable code.
    code0: u32,
    /// Executable code.
    code1: u32,
    /// Image load offset, little endian.
    text_offset: u64,
    /// Effective Image size, little endian.
    image_size: u64,
    /// Kernel flags, little endian.
    flags: u64,
    /// Reserved.
    res2: u64 = 0,
    /// Reserved.
    res3: u64 = 0,
    /// Reserved.
    res4: u64 = 0,
    /// MAgic number, little endian, "ARM\x64".
    magic: u32,
    /// Reserved.
    res5: u32 = 0,

    comptime {
        hugin.comptimeAssert(@bitSizeOf(KernelHeader) == 64 * 8, "Invalid KernelHeader size", .{});
    }
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.vm);
const hugin = @import("hugin");
const arch = hugin.arch;
const bits = hugin.bits;
const mmio = hugin.mmio;
const rtt = hugin.rtt;
const allocator = hugin.mem.general_allocator;
const palloc = hugin.mem.page_allocator;

const MmioError = mmio.MmioError;
const SinglyLinkedList = std.SinglyLinkedList;
const Virt = hugin.mem.Virt;
const Phys = hugin.mem.Phys;
