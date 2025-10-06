//! Arm Generic Timer.

const Error = error{
    /// Generic timer or its feature is not found.
    NotFound,
} || hugin.dtb.DtbError || hugin.intr.IntrError;

/// DTB interrupt type for GICv3 PPI.
const dtb_gic_ppi = 1;

/// Physical interrupt ID of EL1 Virtual Timer.
var pintid_offset: intr.IntrId = undefined;
/// Virtual interrupt ID of EL1 Virtual Timer.
///
/// "virtual" here means "to a guest OS".
const vintid = 27;

/// Initialize the timer globally.
pub fn initGlobal(dtb: hugin.dtb.Dtb) Error!void {
    const node = try dtb.searchNode(
        .{ .compat = "arm,armv8-timer" },
        null,
    ) orelse return Error.NotFound;
    const prop = try dtb.getProp(node, "interrupts") orelse return Error.NotFound;
    const ints = prop.slice();

    if (bits.fromBigEndian(ints[6]) == dtb_gic_ppi) {
        pintid_offset = @intCast(bits.fromBigEndian(ints[7]));
    } else {
        return Error.NotFound;
    }
}

/// Initialize the timer per CPU.
pub fn initLocal() Error!void {
    // Initialize the counter.
    arch.am.msr(.cntvoff_el2, arch.regs.Cntvoff{ .offset = 0 });

    // Enable interrupt.
    try intr.enable(pintid_offset, .ppi, timerHandler);
}

var cnt: usize = 0;

/// Timer interrupt handler
fn timerHandler(_: *arch.regs.Context) bool {
    hugin.vm.current().gicredist.inject(
        vintid,
        pintid_offset + intr.ppi_base,
    );
    //std.log.debug("timer: {d}", .{cnt});
    cnt += 1;

    // Do not deactivate the interrupt since vGIC does it instead.
    return false;
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const arch = hugin.arch;
const bits = hugin.bits;
const intr = hugin.intr;
