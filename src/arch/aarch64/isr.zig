extern const exception_table: *void;

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
    log.err(
        "!!! IRQ: LR=0x{X}, ESR={X:0>16}",
        .{ lr.addr, @as(u64, @bitCast(sr)) },
    );

    _ = ctx;
    @panic("");
}

/// Synchronous exception handler for EL2.
export fn syncHandler(ctx: *Context) callconv(.c) void {
    const sr = am.mrs(.esr_el2);

    switch (sr.ec) {
        // Instruction abort.
        .iabort_lower, .iabort_cur => instAbortHandler(ctx),

        // Data abort.
        .dabort_lower, .dabort_cur => dataAbortHandler(ctx),

        // Unhandled exception.
        else => {
            log.err("Unknown synchronous exception: {d}", .{sr.ec});
            @panic("Abort.");
        },
    }
}

/// Instruction abort handler.
fn instAbortHandler(_: *Context) noreturn {
    const lr = am.mrs(.elr_el2);
    const sr = am.mrs(.esr_el2);

    const ifsc: regs.Esr.Ifsc = @enumFromInt(@as(u6, @truncate(sr.iss)));
    const far = am.mrs(.far_el2);
    const hcr_el2 = am.mrs(.hcr_el2);
    log.err("Instruction abort: {t} @ 0x{X:0>16}", .{ ifsc, lr.addr });
    log.err("FAR=0x{X}, HCR=0x{X:0>16}", .{ far.addr, @as(u64, @bitCast(hcr_el2)) });

    if (paging.lookup(far.addr)) |pa| {
        log.err("IPA 0x{X:0>16} -> PA 0x{X:0>16}", .{ far.addr, pa });
    } else {
        log.err("IPA 0x{X:0>16} -> (not mapped)", .{far.addr});
    }

    @panic("Abort.");
}

/// Data abort handler.
fn dataAbortHandler(ctx: *Context) void {
    const sr = am.mrs(.esr_el2);
    const iss: regs.Esr.IssDabort = @bitCast(sr.iss);

    if (!iss.isv) {
        @panic("DFSC.ISV is not set, indicating no Instruction Syndrome is available.");
    }

    // Print faulting information.
    const reg = &@as([*]u64, @ptrCast(ctx))[iss.srt_wu];
    const hpfar = am.mrs(.hpfar_el2);
    const far = am.mrs(.far_el2);
    const fipa = hpfar.ipa() | (far.addr & hugin.mem.page_mask);

    // Call MMIO handlers.
    const width = getRegisterWidth(iss.sas);
    _ = switch (iss.wnr) {
        .write => mmio.write(fipa, reg, width),
        .read => mmio.read(fipa, reg, width),
    } catch |err| {
        log.err("Failed to handle MMIO on 0x{X:0>16}: {t}", .{ fipa, err });
        @panic("Abort.");
    };

    // Advance ELR.
    const elr = am.mrs(.elr_el2);
    const next_elr: regs.Elr = .{ .addr = elr.addr + 4 };
    am.msr(.elr_el2, next_elr);
}

/// Get access width in bytes from SAS field.
fn getRegisterWidth(sas: @FieldType(regs.Esr.IssDabort, "sas")) mmio.Width {
    return switch (sas) {
        .byte => .byte,
        .halfword => .hword,
        .word => .word,
        .doubleword => .dword,
    };
}
// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.isr);

const hugin = @import("hugin");
const bits = hugin.bits;
const mmio = hugin.mmio;

const am = @import("asm.zig");
const paging = @import("paging.zig");
const regs = @import("registers.zig");
