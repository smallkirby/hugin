pub const Error = hugin.mem.PageAllocator.Error || hugin.mmio.MmioError;

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
    /// List head of VMs.
    _node: SinglyLinkedList.Node = .{},

    /// Dispatch an MMIO read handler for the given address.
    pub fn mmioRead(self: *Self, addr: usize, width: mmio.Width) mmio.Register {
        var device = self.devices.first;
        while (device) |dev| : (device = dev.next) {
            const mdev: *MmioDevice = @fieldParentPtr("_node", dev);
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
};

/// Initialize the VM subsystem.
pub fn init() Error!void {
    const vbase = 0x4000_0000;
    const vsize = 256 * hugin.mem.mib;

    // Allocate resources for the VM.
    const pram = try palloc.allocPages(vsize / hugin.mem.page_size);
    const vmid = blk: {
        const tmp = next_vmid;
        next_vmid += 1;
        break :blk tmp;
    };

    // Setup Stage 2 Translation.
    try hugin.arch.initPaging(
        vbase,
        @intFromPtr(pram.ptr),
        pram.len,
        hugin.mem.page_allocator,
    );

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

    // Create the VM instance.
    const vm = try allocator.create(Vm);
    vm.* = Vm{
        .vmid = vmid,
        .ram_vbase = vbase,
        .ram_pbase = @intFromPtr(pram.ptr),
        .ram_size = pram.len,
        .devices = .{},
    };
    vms.prepend(&vm._node);

    // Add MMIO devices.
    {
        const pl011 = try mmio.pl001.Device.new(allocator);
        vm.devices.prepend(&pl011.interface._node);
    }
}

/// Get the current VM instance.
pub fn current() *Vm {
    return @fieldParentPtr("_node", vms.first.?);
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.vm);
const hugin = @import("hugin");
const mmio = hugin.mmio;
const allocator = hugin.mem.general_allocator;
const palloc = hugin.mem.page_allocator;

const MmioError = mmio.MmioError;
const SinglyLinkedList = std.SinglyLinkedList;
const Virt = hugin.mem.Virt;
const Phys = hugin.mem.Phys;
