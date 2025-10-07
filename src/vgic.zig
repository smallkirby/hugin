/// Initialize vGIC.
pub fn init() hugin.intr.IntrError!void {
    // Global enable vGIC.
    arch.am.msr(.ich_hcr_el2, std.mem.zeroInit(arch.regs.IchHcr, .{
        .en = true,
    }));
}

/// Register a virtual interrupt entry to the vGIC.
pub fn pushVintr(intid: intr.IntrId, group: u1, prio: intr.Priority, pintid: ?intr.IntrId) void {
    const num_lrn: usize = arch.am.mrs(.ich_vtr_el2).list_regs + 1;
    const normed_num_lrn = @min(num_lrn, num_lrns);

    for (0..normed_num_lrn) |i| {
        var lr = getListRegister(i);

        // Empty entry.
        if (lr.state == .inactive) {
            return setListRegister(i, .{
                .vintid = intid,
                .pintid = if (pintid) |id| id else 0,
                .prio = prio,
                .group = group,
                .hw = if (pintid) |_| true else false,
                .state = .pending,
                .nmi = false,
            });
        }

        // Same entry.
        if (lr.vintid == intid) {
            lr.state = if (lr.state == .active) .pending_active else .pending;
            return setListRegister(i, lr);
        }
    }

    @panic("No available List Register.");
}

/// Number of ICC_LRn_EL1 registers.
const num_lrns = 16;

fn getListRegister(index: usize) arch.regs.IchLr {
    return switch (index) {
        0 => arch.am.mrs(.ich_lr0_el2),
        1 => arch.am.mrs(.ich_lr1_el2),
        2 => arch.am.mrs(.ich_lr2_el2),
        3 => arch.am.mrs(.ich_lr3_el2),
        4 => arch.am.mrs(.ich_lr4_el2),
        5 => arch.am.mrs(.ich_lr5_el2),
        6 => arch.am.mrs(.ich_lr6_el2),
        7 => arch.am.mrs(.ich_lr7_el2),
        8 => arch.am.mrs(.ich_lr8_el2),
        9 => arch.am.mrs(.ich_lr9_el2),
        10 => arch.am.mrs(.ich_lr10_el2),
        11 => arch.am.mrs(.ich_lr11_el2),
        12 => arch.am.mrs(.ich_lr12_el2),
        13 => arch.am.mrs(.ich_lr13_el2),
        14 => arch.am.mrs(.ich_lr14_el2),
        15 => arch.am.mrs(.ich_lr15_el2),
        else => @panic("Invalid index."),
    };
}

fn setListRegister(index: usize, lr: arch.regs.IchLr) void {
    switch (index) {
        0 => arch.am.msr(.ich_lr0_el2, lr),
        1 => arch.am.msr(.ich_lr1_el2, lr),
        2 => arch.am.msr(.ich_lr2_el2, lr),
        3 => arch.am.msr(.ich_lr3_el2, lr),
        4 => arch.am.msr(.ich_lr4_el2, lr),
        5 => arch.am.msr(.ich_lr5_el2, lr),
        6 => arch.am.msr(.ich_lr6_el2, lr),
        7 => arch.am.msr(.ich_lr7_el2, lr),
        8 => arch.am.msr(.ich_lr8_el2, lr),
        9 => arch.am.msr(.ich_lr9_el2, lr),
        10 => arch.am.msr(.ich_lr10_el2, lr),
        11 => arch.am.msr(.ich_lr11_el2, lr),
        12 => arch.am.msr(.ich_lr12_el2, lr),
        13 => arch.am.msr(.ich_lr13_el2, lr),
        14 => arch.am.msr(.ich_lr14_el2, lr),
        15 => arch.am.msr(.ich_lr15_el2, lr),
        else => @panic("Invalid index."),
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const arch = hugin.arch;
const intr = hugin.intr;
