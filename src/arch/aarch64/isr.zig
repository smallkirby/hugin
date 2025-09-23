extern const exception_table: *void;

/// Setup exception handlers for EL2.
pub fn init() void {
    const vbar = regs.Vbar{
        .addr = @intFromPtr(&exception_table),
    };
    am.msr(.vbar_el2, vbar);
}

/// IRQ handler for EL2.
export fn irqHandler(ctx: *Context) callconv(.c) void {
    const lr = am.mrs(.elr_el2);
    const sr = am.mrs(.esr_el2);
    log.debug(
        "IRQ: LR=0x{X}, ESR={X:0>16}",
        .{ lr.addr, @as(u64, @bitCast(sr)) },
    );

    _ = ctx;
    @panic("");
}

/// Synchronous exception handler for EL2.
export fn syncHandler(ctx: *Context) callconv(.c) void {
    const lr = am.mrs(.elr_el2);
    const sr = am.mrs(.esr_el2);
    log.debug(
        "Synchronous exception: ELR=0x{X}, ESR={X:0>16}",
        .{ lr.addr, @as(u64, @bitCast(sr)) },
    );

    _ = ctx;
    @panic("");
}

/// Exception context.
const Context = extern struct {
    x0: u64,
    x1: u64,
    x2: u64,
    x3: u64,
    x4: u64,
    x5: u64,
    x6: u64,
    x7: u64,
    x8: u64,
    x9: u64,
    x10: u64,
    x11: u64,
    x12: u64,
    x13: u64,
    x14: u64,
    x15: u64,
    x16: u64,
    x17: u64,
    x18: u64,
    x19: u64,
    x20: u64,
    x21: u64,
    x22: u64,
    x23: u64,
    x24: u64,
    x25: u64,
    x26: u64,
    x27: u64,
    x28: u64,
    x29: u64,
    x30: u64,
    _pad: u64,
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.isr);

const am = @import("asm.zig");
const regs = @import("registers.zig");
