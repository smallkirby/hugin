const Error = mmio.MmioError;

/// GICv3 Distributor virtual MMIO device.
pub const DistributorDevice = struct {
    const Self = @This();
    const Register = mmio.Register;

    /// MMIO device interface.
    interface: hugin.vm.MmioDevice,

    // Virtual registers.
    ctlr: Ctlr,
    igroupr: [32]Igroupr,
    enable: [32]Isenabler,
    pending: [32]Ispendr,
    active: [32]Iactiver,
    ipriorityr: [255]Ipriorityr,
    icfgr: [64]Icfgr,
    igrpmodr: [32]Igrpmodr,
    irouter: [1020]Irouter,

    const handler = hugin.vm.MmioDevice.Handler{
        .read = &read,
        .write = &write,
    };

    pub fn new(allocator: Allocator, base: usize, len: usize) Error!*Self {
        const self = try allocator.create(Self);
        self.* = std.mem.zeroInit(Self, .{
            .interface = initInterface(self, base, len),
        });

        return self;
    }

    fn initInterface(self: *Self, base: usize, len: usize) hugin.vm.MmioDevice {
        return .{
            .ctx = @ptrCast(self),
            .base = base,
            .len = len,
            .handler = handler,
        };
    }

    /// MMIO read handler.
    pub fn read(ctx: *anyopaque, offset: usize, width: mmio.Width) Error!Register {
        const self: *Self = @ptrCast(@alignCast(ctx));

        return switch (offset) {
            // GICD_CTLR.
            map.ctlr => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = @bitCast(self.ctlr) };
            },

            // GICD_TYPER.
            map.typer => blk: {
                try assertWidth(width, .word);
                break :blk Register{
                    .word = @bitCast(std.mem.zeroInit(Typer, .{
                        .it_lines_number = 31, // 988 SPIs
                        .no1n = true,
                    })),
                };
            },

            // GICD_IIDR.
            map.iidr => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = 0 };
            },

            // GICD_TYPER2.
            map.typer2 => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = 0 };
            },

            // GICD_IGROUPR<n>.
            map.igroupr...map.igroupr + @sizeOf(@TypeOf(self.igroupr)) - 1 => blk: {
                try assertWidth(width, .word);
                const idx = (offset - map.igroupr) / @sizeOf(Igroupr);
                break :blk Register{ .word = self.igroupr[idx] };
            },

            // GICD_ISENABLER<n>.
            map.isenabler...map.isenabler + @sizeOf(@TypeOf(self.enable)) - 1 => blk: {
                try assertWidth(width, .word);
                const idx = (offset - map.isenabler) / @sizeOf(Isenabler);
                break :blk Register{ .word = self.enable[idx] };
            },
            // GICD_ICENABLER<n>.
            map.icenabler...map.icenabler + @sizeOf(@TypeOf(self.enable)) - 1 => blk: {
                try assertWidth(width, .word);
                const idx = (offset - map.icenabler) / @sizeOf(Isenabler);
                break :blk Register{ .word = self.enable[idx] };
            },

            // GICD_ISPENDR<n>.
            map.ispendr...map.ispendr + @sizeOf(@TypeOf(self.pending)) - 1 => blk: {
                try assertWidth(width, .word);
                const idx = (offset - map.ispendr) / @sizeOf(Ispendr);
                break :blk Register{ .word = self.pending[idx] };
            },
            // GICD_ICPENDR<n>.
            map.icpendr...map.icpendr + @sizeOf(@TypeOf(self.pending)) - 1 => blk: {
                try assertWidth(width, .word);
                const idx = (offset - map.icpendr) / @sizeOf(Ispendr);
                break :blk Register{ .word = self.pending[idx] };
            },

            // GICD_PIDR2.
            map.pidr2 => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = @bitCast(Pidr2{}) };
            },

            else => {
                log.err("Unhandled GICv3 Distributor read at offset 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        };
    }

    /// MMIO write handler.
    pub fn write(ctx: *anyopaque, offset: usize, value: Register) Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        switch (offset) {
            // GICD_CTLR.
            map.ctlr => {
                try assertWidth(value, .word);
                self.ctlr = @bitCast(value.word);
            },

            // GICD_GROUPR<n>.
            map.igroupr...map.igroupr + @sizeOf(@TypeOf(self.igroupr)) - 1 => {
                try assertWidth(value, .word);
                const idx = (offset - map.igroupr) / @sizeOf(Igroupr);
                self.igroupr[idx] = value.word;
            },

            // GICD_ICENABLER<n>.
            map.icenabler...map.icenabler + @sizeOf(@TypeOf(self.enable)) - 1 => {
                try assertWidth(value, .word);
                const idx = (offset - map.icenabler) / @sizeOf(Isenabler);
                self.enable[idx] &= ~value.word;
            },

            // GICD_ICACTIVER<n>.
            map.icactiver...map.icactiver + @sizeOf(@TypeOf(self.active)) - 1 => {
                try assertWidth(value, .word);
                const idx = (offset - map.icactiver) / @sizeOf(Iactiver);
                self.active[idx] &= ~value.word;
            },

            // GICD_IPRIORITYR<n>.
            map.ipriorityr...map.ipriorityr + @sizeOf(@TypeOf(self.ipriorityr)) - 1 => {
                try assertWidth(value, .word);
                const idx = (offset - map.ipriorityr) / @sizeOf(Ipriorityr);
                self.ipriorityr[idx] = @bitCast(value.word);
            },

            // GICD_ICFGR<n>.
            map.icfgr...map.icfgr + @sizeOf(@TypeOf(self.icfgr)) - 1 => {
                try assertWidth(value, .word);
                const idx = (offset - map.icfgr) / @sizeOf(Icfgr);
                self.icfgr[idx] = value.word;
            },

            // GICD_IROUTER<n>.
            map.irouter...map.irouter + @sizeOf(@TypeOf(self.irouter)) - 1 => {
                try assertWidth(value, .dword);
                const idx = (offset - map.irouter) / @sizeOf(Irouter);
                self.irouter[idx] = value.dword;
            },

            else => {
                log.err("Unhandled GICv3 Distributor write at offset 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        }
    }

    /// Register map.
    const map = struct {
        /// Distributor Control Register.
        const ctlr = 0x0000;
        /// Interrupt Controller Type Register.
        const typer = 0x0004;
        /// Distributor Implementer Identification Register.
        const iidr = 0x0008;
        /// Interrupt Controller Type Register 2.
        const typer2 = 0x000C;
        /// Interrupt Group Registers.
        const igroupr = 0x0080;
        /// Interrupt Set-Enable Registers.
        const isenabler = 0x0100;
        /// Interrupt Clear-Enable Registers.
        const icenabler = 0x0180;
        /// Interrupt Set-Pending Registers.
        const ispendr = 0x0200;
        /// Interrupt Clear-Pending Registers.
        const icpendr = 0x0280;
        /// Interrupt Clear-Active Registers.
        const icactiver = 0x380;
        /// Interrupt Priority Registers.
        const ipriorityr = 0x0400;
        /// Interrupt Configuration Registers.
        const icfgr = 0x0C00;
        /// Interrupt Group Modifier Registers.
        const igrpmodr = 0x0D00;
        /// Interrupt Routing Registers.
        const irouter = 0x6000;
        //// Distributor Peripheral ID2 Register.
        const pidr2 = 0xFFE8;
    };

    /// GICD_CTLR.
    ///
    /// Enables interrupts and affinity routing.
    const Ctlr = packed struct(u32) {
        /// When `.are_ns` is set, Enable Group 0 interrupts. Otherwise, reserved.
        enable_grp0: bool,
        /// When `.are_ns` is set, Enable Group 1 interrupts. Otherwise, reserved.
        enable_grp1: bool,
        /// Reserved.
        _reserved0: u2 = 0,
        /// Affinity routing enable.
        are_ns: bool,
        /// Reserved.
        _reserved1: u26 = 0,
        /// Register Write Pending (RO).
        ///
        /// Indicates that a write operation to the GICD_CTLR is in progress.
        rwp: bool,
    };

    /// GICD_TYPER.
    const Typer = packed struct(u32) {
        /// Indicates the maximum SPI supported.
        it_lines_number: u5,
        /// Number of PEs that can be used when affinity routing is not enabled, minus 1.
        cpus_number: u3,
        /// Extended SPI.
        espi: bool,
        /// Non-maskable Interrupts.
        nmi: bool,
        /// Indicates whether the GIC implementation supports two Security states.
        security_extn: bool,
        /// Number of supported LPIS.
        num_lpis: u5,
        /// Indicates whether the implementation supports message-based interrupts by writing to Distributor registers.
        mbis: bool,
        /// Indicates whether the implementation supports LPIs.
        lpis: bool,
        /// Reserved.
        dvis: bool = false,
        /// The number of interrupt identifier bits supported, minus 1.
        idbits: u5,
        /// Affinity 3 valid.
        a3v: bool,
        /// Indicates whether 1 of N SPI interrupts are supported.
        no1n: bool,
        /// Range Selector Support.
        rss: bool,
        /// Reserved.
        espi_range: u5 = 0,
    };

    /// GICD_IIDR.
    const Iidr = packed struct(u32) {
        /// JEP106 code of the company that implemented the Distributor.
        implementer: u12,
        /// Revision number.
        revision: u4,
        /// Variant number.
        variant: u4,
        /// Reserved.
        _reserved: u4 = 0,
        /// Product ID.
        product: u8,
    };

    /// GICD_TYPER2.
    const Typer2 = packed struct(u32) {
        /// The number of bits is equal to the bits of vPEID minus one.
        vid: u5,
        /// Reserved.
        _reserved0: u2 = 0,
        /// Indicates whether 16bits of vPEID are implemented.
        vil: bool,
        /// Indicates whether SGIs can be configured to not have an active state.
        nassgicap: bool,
        /// Reserved.
        _reserved1: u24 = 0,
    };

    /// GICD_ISENABLER<n>.
    ///
    /// Enables forwarding of the corresponding interrupt.
    /// Consists of 32 bits, each bit corresponds to an interrupt.
    const Isenabler = u32;

    /// GICD_ICACTIVER<n>.
    ///
    /// Deactivates the corresponding interrupt.
    const Iactiver = u32;

    /// GICD_IPRIORITYR<n>.
    ///
    /// Holds the priority of corresponding interrupt.
    /// Each register holds 4 interrupt priorities.
    const Ipriorityr = packed struct(u32) {
        prio0: Priority,
        prio1: Priority,
        prio2: Priority,
        prio3: Priority,
    };

    /// GICD_ICFGR<n>.
    ///
    /// Determines whether the corresponding interrupt is edge-triggered or level-sensitive.
    const Icfgr = u32;

    /// Interrupt trigger type.
    const Trigger = enum(u2) {
        level = 0b00,
        edge = 0b10,
    };

    /// GICD_IGRPMODR<n>.
    ///
    /// When affinity routing is enabled, the bit corresponding to an interrupt is cancatenated to GICD_IGROUPR<n>
    /// to form a 2-bit field that determines the interrupt's group.
    const Igrpmodr = u32;

    /// GICD_IGROUPR<n>.
    ///
    /// See GICD_IGRPMODR<n>.
    const Igroupr = u32;

    /// Interrupt group.
    ///
    /// (modifier, group):
    /// - (0, 0): Secure Group 0
    /// - (0, 1): Non-secure Group 1
    /// - (1, 0): Secure Group 1
    /// - (1, 1): Reserved.
    const Group = enum(u2) {
        secure_grp0 = 0,
        ns_grp1 = 1,
        secure_grp1 = 2,
        reserved = 3,
    };

    /// GICD_IROUTER<n>.
    const Irouter = u64;

    /// GICD_ISPENDR<n>.
    ///
    /// Adds the pending state to the corresponding interrupt.
    const Ispendr = u32;

    /// GICD_ICPENDR<n>.
    ///
    /// Removes the pending state of the corresponding interrupt.
    const Icpendr = u32;

    /// GICD_PIDR2.
    ///
    /// Provides a architecturally-defined architecture revision field.
    const Pidr2 = packed struct(u32) {
        /// Implementation defined.
        impl: u4 = 0,
        /// Revision field for the GIC architecture.
        rev: Revision = .gicv3,
        /// Reserved.
        _reserved: u24 = 0,

        const Revision = enum(u4) {
            gicv1 = 0x1,
            gicv2 = 0x2,
            gicv3 = 0x3,
            gicv4 = 0x4,
            _,
        };
    };
};

/// GICv3 Redistributor virtual MMIO device.
pub const RedistributorDevice = struct {
    const Self = @This();
    const Register = mmio.Register;

    /// MMIO device interface.
    interface: hugin.vm.MmioDevice,

    // Virtual registers.
    affinity: u32,
    ctlr: Ctlr,
    waker: Waker,
    group: u32,
    enable: u32,
    pending: u32,
    config: [2]u32,
    prio: [8]Ipriorityr,

    const handler = hugin.vm.MmioDevice.Handler{
        .read = &read,
        .write = &write,
    };

    pub fn new(allocator: Allocator, base: usize, len: usize) Error!*Self {
        const self = try allocator.create(Self);
        self.* = std.mem.zeroInit(Self, .{
            .waker = .{ .ca = true },
            .affinity = arch.am.mrs(.mpidr_el1).packedAffinity(),
            .interface = initInterface(self, base, len),
        });

        return self;
    }

    fn initInterface(self: *Self, base: usize, len: usize) hugin.vm.MmioDevice {
        return .{
            .ctx = @ptrCast(self),
            .base = base,
            .len = len,
            .handler = handler,
        };
    }

    /// MMIO read handler.
    pub fn read(ctx: *anyopaque, offset: usize, width: mmio.Width) Error!Register {
        const self: *Self = @ptrCast(@alignCast(ctx));

        return switch (offset) {
            // GICR_CTLR.
            map.ctlr => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = @bitCast(self.ctlr) };
            },

            // GICR_TYPER.
            map.typer => blk: {
                try assertWidth(width, .dword);
                break :blk Register{ .dword = @bitCast(std.mem.zeroInit(Typer, .{
                    .last = true,
                    .affinity = self.affinity,
                })) };
            },

            // GICR_WAKER.
            map.waker => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = @bitCast(self.waker) };
            },

            // GICR_PIDR2.
            map.pidr2 => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = @bitCast(Pidr2{}) };
            },

            // GICR_ICFGR0.
            map.icfgr0 => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = self.config[0] };
            },
            // GICR_ICFGR1.
            map.icfgr1 => blk: {
                try assertWidth(width, .word);
                break :blk Register{ .word = self.config[1] };
            },

            else => {
                log.err("Unhandled GICv3 Redistributor read at offset 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        };
    }

    /// MMIO write handler.
    pub fn write(ctx: *anyopaque, offset: usize, value: Register) Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        switch (offset) {
            // GICR_WAKER.
            map.waker => {
                try assertWidth(value, .word);
                const raw: Waker = @bitCast(value.word);
                self.waker = @bitCast(Waker{
                    .ps = raw.ps,
                    .ca = raw.ps,
                });
            },

            // GICR_IGROUPR0.
            map.igroupr => {
                try assertWidth(value, .word);
                self.group = value.word;
            },

            // GICR_ISENABLER0.
            map.isenabler0 => {
                try assertWidth(value, .word);
                self.enable |= value.word;

                for (0..32) |i| {
                    if (bits.isset(value.word, i) and bits.isset(self.pending, i)) {
                        self.inject(@intCast(i), null);
                    }
                }
            },

            // GICR_ICENABLER0.
            map.icenabler0 => {
                try assertWidth(value, .word);
                self.enable &= ~value.word;
            },

            // GICR_ICACTIVER0.
            map.icactiver0 => {
                try assertWidth(value, .word);
                self.enable &= ~value.word;
            },

            // GICR_IPRIORITYR<n>.
            map.ipriorityr0...map.ipriorityr0 + @sizeOf(@TypeOf(self.prio)) - 1 => {
                try assertWidth(value, .word);
                const idx = (offset - map.ipriorityr0) / @sizeOf(Ipriorityr);
                self.prio[idx] = @bitCast(value.word);
            },

            // GICR_ICFGR0.
            map.icfgr0 => {
                try assertWidth(value, .word);
                self.config[0] = value.word;
            },
            // GICR_ICFGR1.
            map.icfgr1 => {
                try assertWidth(value, .word);
                self.config[1] = value.word;
            },

            else => {
                log.err("Unhandled GICv3 Redistributor write at offset 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        }
    }

    /// Inject a virtual interrupt.
    fn inject(self: *const Self, intid: u32, pintid: ?u32) void {
        _ = self;
        _ = intid;
        _ = pintid;

        hugin.unimplemented("RedistributorDevice.inject");
    }

    /// Register map.
    const map = struct {
        /// Redistributor Control Register.
        const ctlr = 0x0000;
        /// Redistributor Type Register.
        const typer = 0x0008;
        /// Redistributor Wake Register.
        const waker = 0x0014;
        /// Distributor Peripheral ID2 Register.
        const pidr2 = 0xFFE8;

        /// Interrupt Group Register 0.
        const igroupr = 0x0001_0080;
        /// Interrupt Set-Enable Register 0.
        const isenabler0 = 0x0001_0100;
        /// Interrupt Clear-Enable Register 0.
        const icenabler0 = 0x0001_0180;
        /// Interrupt Clear-Enable Register 0.
        const icactiver0 = 0x0001_0380;
        /// Interrupt Priority Registers.
        const ipriorityr0 = 0x0001_0400;
        /// PPI Configuration Register 0.
        const icfgr0 = 0x0001_0C00;
        /// PPI Configuration Register 1.
        const icfgr1 = 0x0001_0C04;
    };

    /// GICR_CTLR.
    const Ctlr = packed struct(u32) {
        /// LPI support.
        enable_lpis: bool,
        /// Clear Enable Supported.
        ces: bool,
        /// LPI invalidate registers supported.
        ir: bool,
        /// Register Write Pending (RO).
        rwp: bool,
        /// Reserved.
        _reserved0: u20 = 0,
        /// Disable Processor selection for Group 0 interrupts.
        dpg0: bool,
        /// Disable Processor selection for Group 1 Non-secure interrupts.
        dpg1ns: bool,
        /// Disable Processor selection for Group 1 Secure interrupts.
        dpg1s: bool,
        /// Reserved.
        _reserved1: u4 = 0,
        /// Upstream Write Pending (RO).
        uwp: bool,
    };

    /// GICR_TYPER.
    ///
    /// Provides information about the configuration of the redistributor.
    const Typer = packed struct(u64) {
        /// Whether the GIC implementation supports physical LPIs.
        plpis: bool,
        /// Whether the GIC implementation supports virtual LPIs.
        vlpis: bool,
        /// Dirty.
        dirty: bool,
        /// Whether this Redistributor supports direct injection of LPIs.
        directlpis: bool,
        /// Last Redistributor in the system.
        last: bool,
        /// Implementation Defined.
        dpgs: bool,
        /// Reserved.
        mpam: u1 = 0,
        /// Reserved.
        rvpeid: u1 = 0,
        /// Unique identifier for the PE.
        pn: u16,
        /// Indicates the scope of the CommonLPIAff group.
        common_lapi_aff: u2,
        /// Reserved.
        vsgi: u1 = 0,
        /// Reserved.
        ppinum: u5 = 0,
        /// ID of the PE associated with this Redistributor.
        affinity: u32,
    };

    /// GICR_WAKER.
    ///
    /// Permits software to control the behavior of the WakeRequest power management signal.
    const Waker = packed struct(u32) {
        /// Implementation Defined.
        impl_defined0: bool = false,
        /// Processor Sleep.
        ps: bool,
        /// ChildrenAsleep.
        ca: bool,
        /// Reserved.
        _reserved: u28 = 0,
        /// Implementation Defined.
        impl_defined1: bool = false,
    };

    /// GICR_PIDR2.
    const Pidr2 = DistributorDevice.Pidr2;

    /// GICR_IGROUPR<n>.
    ///
    /// See GICR_IGRPMODR<n>.
    const Igroupr = u32;

    /// GICR_ISENABLER0.
    const Isenabler = u32;

    /// GICR_ICENABLER0.
    const Icenabler = u32;

    /// GICR_ICACTIVER0.
    const Iactiver = u32;

    /// GICR_IPRIORITYR<n>.
    ///
    /// Holds the priority of corresponding interrupt.
    /// Each register holds 4 interrupt priorities.
    const Ipriorityr = packed struct(u32) {
        prio0: Priority,
        prio1: Priority,
        prio2: Priority,
        prio3: Priority,
    };

    /// GICR_ICFGR1.
    ///
    /// Determines whether the corresponding PPI is edge-triggered or level-sensitive.
    /// Each two bits corresponds to a PPI.
    const Icfgr1 = u32;
};

/// Check access width.
fn assertWidth(width: anytype, comptime expected: mmio.Width) Error!void {
    switch (@TypeOf(width)) {
        mmio.Width => if (width != expected) return Error.InvalidWidth,
        mmio.Register => switch (expected) {
            .byte => if (width != .byte) return Error.InvalidWidth,
            .hword => if (width != .hword) return Error.InvalidWidth,
            .word => if (width != .word) return Error.InvalidWidth,
            .dword => if (width != .dword) return Error.InvalidWidth,
        },
        else => @compileError("Invalid width type."),
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.vgic);
const hugin = @import("hugin");
const arch = hugin.arch;
const bits = hugin.bits;
const intr = hugin.intr;
const mmio = hugin.mmio;

const Allocator = std.mem.Allocator;
const Priority = intr.Priority;
