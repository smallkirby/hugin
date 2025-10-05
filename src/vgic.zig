/// Interrupt ID offset of Maintenance Interrupt within PPI.
const intid_maintenance = 9;

/// Initialize vGIC.
pub fn init() hugin.intr.IntrError!void {
    // Global enable vGIC.
    {
        arch.am.msr(.ich_hcr_el2, std.mem.zeroInit(arch.regs.IchHcr, .{
            .en = true,
        }));
    }

    // Register Maintenance Interrupt handler.
    {
        try intr.enable(intid_maintenance, .ppi, mintrHandler);
    }
}

/// Register a virtual interrupt entry to the vGIC.
pub fn pushVintr(intid: intr.IntrId, group: u1, prio: intr.Priority, pintid: ?intr.IntrId) void {
    const num_lrn: usize = arch.am.mrs(.ich_vtr_el2).list_regs + 1;
    const normed_num_lrn = @min(num_lrn, num_lrns);

    for (0..normed_num_lrn) |i| {
        const lr = getListRegister(i);
        switch (lr.state) {
            .inactive => return setListRegister(i, .{
                .vintid = intid,
                .pintid = if (pintid) |id| id else 0,
                .prio = prio,
                .group = group,
                .hw = if (pintid) |_| true else false,
                .state = .pending,
            }),
            .active => return setListRegister(i, .{
                .vintid = lr.vintid,
                .pintid = lr.pintid,
                .prio = lr.prio,
                .group = lr.group,
                .hw = lr.hw,
                .state = .pending_active,
            }),
            else => {},
        }
    }
}

/// Handler for a maintaenance interrupt that's asserted, in Hugin, when a virtual interrupt is deactivated.
fn mintrHandler(_: *arch.regs.Context) void {
    const num_lrn: usize = arch.am.mrs(.ich_vtr_el2).list_regs + 1;
    const normed_num_lrn = @min(num_lrn, num_lrns);

    for (0..normed_num_lrn) |_| {
        hugin.unimplemented("mintrHandler");
    }
}

/// Number of ICC_LRn_EL1 registers.
const num_lrns = 16;

fn getListRegister(index: usize) arch.regs.IccLr {
    return arch.am.mrs(switch (index) {
        0 => .icc_lr0_el1,
        1 => .icc_lr1_el1,
        2 => .icc_lr2_el1,
        3 => .icc_lr3_el1,
        4 => .icc_lr4_el1,
        5 => .icc_lr5_el1,
        6 => .icc_lr6_el1,
        7 => .icc_lr7_el1,
        8 => .icc_lr8_el1,
        9 => .icc_lr9_el1,
        10 => .icc_lr10_el1,
        11 => .icc_lr11_el1,
        12 => .icc_lr12_el1,
        13 => .icc_lr13_el1,
        14 => .icc_lr14_el1,
        15 => .icc_lr15_el1,
        else => @panic("Invalid index."),
    });
}

fn setListRegister(index: usize, lr: arch.regs.IccLr) void {
    arch.am.msr(switch (index) {
        0 => .icc_lr0_el1,
        1 => .icc_lr1_el1,
        2 => .icc_lr2_el1,
        3 => .icc_lr3_el1,
        4 => .icc_lr4_el1,
        5 => .icc_lr5_el1,
        6 => .icc_lr6_el1,
        7 => .icc_lr7_el1,
        8 => .icc_lr8_el1,
        9 => .icc_lr9_el1,
        10 => .icc_lr10_el1,
        11 => .icc_lr11_el1,
        12 => .icc_lr12_el1,
        13 => .icc_lr13_el1,
        14 => .icc_lr14_el1,
        15 => .icc_lr15_el1,
        else => @panic("Invalid index."),
    }, lr);
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const arch = hugin.arch;
const intr = hugin.intr;
