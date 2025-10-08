//! GIC, Generic Interrupt Controller version 3

/// Provides the routing configuration for SPIs (Shared Peripheral Interrupts).
pub const Distributor = struct {
    const Self = @This();

    /// MMIO base address.
    base: usize,

    /// Register map.
    const map = struct {
        /// Distributor Control Register.
        const ctlr = 0x0000;
        /// Interrupt Group Registers.
        const igroupr = 0x0080;
        /// Interrupt Set-Enable Registers.
        const isenabler = 0x0100;
        /// Interrupt Set-Pending Registers.
        const ispendr = 0x0200;
        /// Interrupt Clear-Pending Registers.
        const icpendr = 0x0280;
        /// Interrupt Priority Registers.
        const ipriorityr = 0x0400;
        /// Interrupt Configuration Registers.
        const icfgr = 0x0C00;
        /// Interrupt Group Modifier Registers.
        const igrpmodr = 0x0D00;
        /// Interrupt Routing Registers.
        const irouter = 0x6100;
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

    /// GICD_ISENABLER<n>.
    ///
    /// Enables forwarding of the corresponding interrupt.
    /// Consists of 32 bits, each bit corresponds to an interrupt.
    const Isenabler = u32;

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

    /// GICD_IGRPMODR<n>.
    ///
    /// When affinity routing is enabled, the bit corresponding to an interrupt is cancatenated to GICD_IGROUPR<n>
    /// to form a 2-bit field that determines the interrupt's group.
    const Igrpmodr = u32;

    /// GICD_IGROUPR<n>.
    ///
    /// See GICD_IGRPMODR<n>.
    const Igroupr = u32;

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

    /// Create a new instance.
    pub fn new(base: PhysRegion) Self {
        return Self{ .base = base.addr };
    }

    /// Initialize the distributor.
    pub fn init(self: Self) void {
        self.write(map.ctlr, std.mem.zeroInit(Ctlr, .{
            .are_ns = true,
        }));
        self.waitRwp();

        self.write(map.ctlr, std.mem.zeroInit(Ctlr, .{
            .are_ns = true,
            .enable_grp1 = true,
        }));
        self.waitRwp();
    }

    /// Set the priority of an interrupt.
    pub fn setPriority(self: Self, id: IntrId, prio: Priority) void {
        const reg_index: usize = id / 4;
        const reg_addr = map.ipriorityr + reg_index * @sizeOf(Ipriorityr);

        var reg_value = self.read(reg_addr, Ipriorityr);
        switch (id % 4) {
            0 => reg_value.prio0 = prio,
            1 => reg_value.prio1 = prio,
            2 => reg_value.prio2 = prio,
            3 => reg_value.prio3 = prio,
            else => unreachable,
        }

        self.write(reg_addr, reg_value);
    }

    /// Set the interrupt group of an interrupt.
    pub fn setGroup(self: Self, id: IntrId, group: Group) void {
        const reg_index: usize = id / @bitSizeOf(Igroupr);
        const nth = id % @bitSizeOf(Igroupr);

        // Set GICD_IGROUPR<n>.
        const igroupr_addr = map.igroupr + reg_index * @sizeOf(Igroupr);
        const igroupr = self.read(igroupr_addr, Igroupr);
        self.write(igroupr_addr, switch (group) {
            .secure_grp0, .secure_grp1 => hugin.bits.unset(igroupr, nth),
            .ns_grp1 => hugin.bits.set(igroupr, nth),
            .reserved => unreachable,
        });

        // Set GICD_IGRPMODR<n>.
        const igrpmodr_addr = map.igrpmodr + reg_index * @sizeOf(Igrpmodr);
        const igrpmodr = self.read(igrpmodr_addr, Igrpmodr);
        self.write(igrpmodr_addr, switch (group) {
            .secure_grp0, .ns_grp1 => hugin.bits.unset(igrpmodr, nth),
            .secure_grp1 => hugin.bits.set(igrpmodr, nth),
            .reserved => unreachable,
        });
    }

    /// Set the trigger type of an interrupt.
    pub fn setTrigger(self: Self, id: IntrId, trigger: Trigger) void {
        const reg_index: usize = id / 16;
        const nth: u5 = @intCast((id % 16) * 2);
        const icfgr_addr = map.icfgr + reg_index * @sizeOf(Icfgr);

        const icfgr = self.read(icfgr_addr, Icfgr);
        const new_icfgr = (icfgr & ~(@as(Icfgr, 0b11) << nth)) | (@as(Icfgr, @intFromEnum(trigger)) << nth);
        self.write(icfgr_addr, new_icfgr);
    }

    /// Set the routing of an interrupt to a specific affinity.
    pub fn setRouting(self: Self, id: IntrId, affinity: u64) void {
        const reg_index: usize = id;
        const irouter_addr = map.irouter + reg_index * @sizeOf(Irouter);
        self.write(irouter_addr, affinity);
    }

    /// Set an interrupt as pending.
    pub fn setPending(self: Self, id: IntrId) void {
        const reg_index = id / @bitSizeOf(Ispendr);
        const nth = id % @bitSizeOf(Ispendr);
        const ispendr_addr = map.ispendr + reg_index * @sizeOf(Ispendr);

        const ispendr = self.read(ispendr_addr, Ispendr);
        self.write(ispendr_addr, hugin.bits.set(ispendr, nth));
    }

    /// Clear the pending state of an interrupt.
    pub fn clearPending(self: Self, id: IntrId) void {
        const reg_index = id / @bitSizeOf(Icpendr);
        const nth = id % @bitSizeOf(Icpendr);
        const icpendr_addr = map.icpendr + reg_index * @sizeOf(Icpendr);

        const icpendr = self.read(icpendr_addr, Icpendr);
        self.write(icpendr_addr, hugin.bits.set(icpendr, nth));
    }

    /// Enable an interrupt.
    pub fn enable(self: Self, id: IntrId) void {
        const reg_index = id / @bitSizeOf(Isenabler);
        const nth = id % @bitSizeOf(Isenabler);
        const isenabler_addr = map.isenabler + reg_index * @sizeOf(Isenabler);

        const isenabler = self.read(isenabler_addr, Isenabler);
        self.write(isenabler_addr, hugin.bits.set(isenabler, nth));
    }

    /// Write to a register.
    fn write(self: Self, offset: usize, value: anytype) void {
        switch (@bitSizeOf(@TypeOf(value))) {
            32 => @as(*volatile u32, @ptrFromInt(self.base + offset)).* = @bitCast(value),
            64 => @as(*volatile u64, @ptrFromInt(self.base + offset)).* = @bitCast(value),
            else => unreachable,
        }
    }

    /// Read from a register.
    fn read(self: Self, offset: usize, T: type) T {
        const value = @as(*volatile u32, @ptrFromInt(self.base + offset)).*;
        return @bitCast(value);
    }

    /// Block until the RWP bit is cleared.
    fn waitRwp(self: Self) void {
        while (self.read(map.ctlr, Ctlr).rwp) {
            std.atomic.spinLoopHint();
        }
    }
};

/// Provides the configuration settings for PPIs (Private Peripheral Interrupts) and SGIs (Software Generated Interrupts).
pub const Redistributor = struct {
    const Self = @This();

    /// Size in bytes of each Redistributor frame.
    const mmio_size = 32 * hugin.mem.size_4kib;

    /// MMIO base address.
    base: usize,

    /// Register map.
    const map = struct {
        /// Redistributor Control Register.
        const ctlr = 0x0000;
        /// Redistributor Type Register.
        const typer = 0x0008;
        /// Redistributor Wake Register.
        const waker = 0x0014;

        /// Interrupt Group Register 0.
        const igroupr = 0x0001_0080;
        /// Interrupt Set-Enable Register 0.
        const isenabler0 = 0x0001_0100;
        /// Interrupt Clear-Enable Register 0.
        const icenabler0 = 0x0001_0180;
        /// Interrupt Group Modifier Register 0.
        const igrpmodr = 0x0001_0D00;
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
        impl_defined0: bool,
        /// Processor Sleep.
        ps: bool,
        /// ChildrenAsleep.
        ca: bool,
        /// Reserved.
        _reserved: u28 = 0,
        /// Implementation Defined.
        impl_defined1: bool,
    };

    /// GICR_IGROUPR<n>.
    ///
    /// See GICR_IGRPMODR<n>.
    const Igroupr = u32;

    /// GICR_IGRPMODR<n>.
    const Igroupmodr = u32;

    /// GICR_ISENABLER0.
    const Isenabler = u32;

    /// GICR_ICENABLER0.
    const Icenabler = u32;

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

    /// GICR_ICFGR<0,1>.
    ///
    /// Determines whether the corresponding PPI is edge-triggered or level-sensitive.
    /// Each two bits corresponds to a PPI.
    const Icfgr = u32;

    /// Create a new instance.
    pub fn new(base: PhysRegion) Self {
        const limit = base.addr + base.size;
        const affinity = am.mrs(.mpidr_el1).packedAffinity();

        var cur = base.addr;
        while (cur < limit) : (cur += mmio_size) {
            const r = Redistributor{ .base = cur };
            const typer = r.read(map.typer, Typer);
            if (typer.affinity == affinity) {
                return r;
            }

            if (typer.last) {
                break;
            }
        }

        @panic("GICv3: No redistributor found for this CPU");
    }

    /// Initialize the redistributor.
    pub fn init(self: Self) void {
        // Set system registers and check if it's supported.
        var iccsre = am.mrs(.icc_sre_el2);
        iccsre.sre = true;
        am.msr(.icc_sre_el2, iccsre);
        if (!am.mrs(.icc_sre_el2).sre) {
            @panic("GICv3: ICC_SRE_EL2 is not supported");
        }

        // Wait until processor gets out of sleep.
        self.waitRwp();
        var waker = self.read(map.waker, Waker);
        waker.ps = false;
        self.write(map.waker, waker);
        while (self.read(map.waker, Waker).ca) {
            std.atomic.spinLoopHint();
        }

        // Set mask and binary point.
        self.setPriorityMask(0xFF);
        self.setBinaryPoint(3);

        // Enable Group 1 interrupt.
        const igrpen1 = std.mem.zeroInit(regs.IccIgrpen1El1, .{
            .enable = true,
        });
        am.msr(.icc_igrpen1_el1, igrpen1);
    }

    /// Set priority mask.
    pub fn setPriorityMask(_: Self, prio: Priority) void {
        const pmr = std.mem.zeroInit(regs.IccPmr, .{
            .priority = prio,
        });
        am.msr(.icc_pmr_el1, pmr);
    }

    /// Enable an interrupt.
    pub fn enable(self: Self, id: IntrId) void {
        hugin.rtt.expect(id < 32);
        self.write(map.isenabler0, hugin.bits.tobit(Isenabler, id));
    }

    /// Set binary point.
    pub fn setBinaryPoint(_: Self, value: u3) void {
        const bpr = std.mem.zeroInit(regs.IccBpr, .{
            .bpr = value,
        });
        am.msr(.icc_bpr1_el1, bpr);
    }

    /// Set the priority of an interrupt.
    pub fn setPriority(self: Self, id: IntrId, prio: Priority) void {
        hugin.rtt.expect(id < 32);

        const reg_index: usize = id / 4;
        const reg_addr = map.ipriorityr0 + reg_index * @sizeOf(Ipriorityr);

        var reg_value = self.read(reg_addr, Ipriorityr);
        switch (id % 4) {
            0 => reg_value.prio0 = prio,
            1 => reg_value.prio1 = prio,
            2 => reg_value.prio2 = prio,
            3 => reg_value.prio3 = prio,
            else => unreachable,
        }

        self.write(reg_addr, reg_value);
    }

    /// Set the interrupt group of an interrupt.
    pub fn setGroup(self: Self, id: IntrId, group: Group) void {
        hugin.rtt.expect(id < 32);

        // Set GICR_IGROUPR<n>.
        const igroupr = self.read(map.igroupr, Igroupr);
        self.write(map.igroupr, switch (group) {
            .secure_grp0, .secure_grp1 => hugin.bits.unset(igroupr, id),
            .ns_grp1 => hugin.bits.set(igroupr, id),
            .reserved => unreachable,
        });

        // Set GICR_IGRPMODR<n>.
        const igrpmodr = self.read(map.igrpmodr, Igroupmodr);
        self.write(map.igrpmodr, switch (group) {
            .secure_grp0, .ns_grp1 => hugin.bits.unset(igrpmodr, id),
            .secure_grp1 => hugin.bits.set(igrpmodr, id),
            .reserved => unreachable,
        });
    }

    /// Set the trigger type of an interrupt.
    pub fn setTrigger(self: Self, id: IntrId, trigger: Trigger) void {
        hugin.rtt.expect(id < 32);

        const cfgr_addr: usize = if (id < 16) map.icfgr0 else map.icfgr1;
        const nth: u5 = @intCast((id % 16) * 2);
        const icfgr = self.read(cfgr_addr, Icfgr);
        const mask: Icfgr = @as(Icfgr, 0b11) << nth;
        const newval = (icfgr & ~mask) | (@as(Icfgr, @intFromEnum(trigger)) << nth);
        self.write(cfgr_addr, newval);
    }

    /// Write to a register.
    fn write(self: Self, offset: usize, value: anytype) void {
        switch (@bitSizeOf(@TypeOf(value))) {
            32 => @as(*volatile u32, @ptrFromInt(self.base + offset)).* = @bitCast(value),
            64 => @as(*volatile u64, @ptrFromInt(self.base + offset)).* = @bitCast(value),
            else => @compileError("gicv3.write: Invalid register size"),
        }
    }

    /// Read from a register.
    fn read(self: Self, offset: usize, T: type) T {
        return @bitCast(switch (@bitSizeOf(T)) {
            32 => @as(*volatile u32, @ptrFromInt(self.base + offset)).*,
            64 => @as(*volatile u64, @ptrFromInt(self.base + offset)).*,
            else => @compileError("gicv3.read: Invalid register size"),
        });
    }

    /// Block until the RWP bit is cleared.
    fn waitRwp(self: Self) void {
        while (self.read(map.ctlr, Ctlr).rwp) {
            std.atomic.spinLoopHint();
        }
    }
};

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

/// Interrupt trigger type.
const Trigger = enum(u2) {
    level = 0b00,
    edge = 0b10,
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const am = @import("asm.zig");
const regs = @import("registers.zig");

const IntrId = hugin.intr.IntrId;
const Priority = hugin.intr.Priority;
const PhysRegion = hugin.mem.PhysRegion;
const SpinLock = hugin.SpinLock;
