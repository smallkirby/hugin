extern const exception_table: *void;

/// Setup exception handlers for EL2.
pub fn init() void {
    // Set vector base address.
    const vbar = regs.Vbar{
        .addr = @intFromPtr(&exception_table),
    };
    am.msr(.vbar_el2, vbar);

    // Setup GIC CPU interface.
    var ctlr = am.mrs(.icc_ctlr_el1);
    ctlr.eoimode = .deactivates;
    am.msr(.icc_ctlr_el1, ctlr);
}

/// IRQ handler for EL2.
export fn irqHandler(ctx: *Context) callconv(.c) void {
    const intid = am.mrs(.icc_iar1_el1).intid;
    const lr = am.mrs(.elr_el2);
    const sr = am.mrs(.esr_el2);
    log.err(
        "!!! IRQ#{d}: LR=0x{X}, ESR={X:0>16}",
        .{ intid, lr.addr, @as(u64, @bitCast(sr)) },
    );

    // Handle the interrupt.
    hugin.intr.dispatch(intid, ctx);

    // Send EOI.
    const eoir: regs.IccEoir1El1 = .{ .intid = intid };
    am.msr(.icc_eoir1_el1, eoir);
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
    switch (iss.wnr) {
        .read => {
            const width = getRegisterWidth(iss.sas);
            reg.* = switch (vm.current().mmioRead(fipa, width)) {
                inline else => |v| bits.embed(reg.*, v, 0),
            };
        },
        .write => {
            const regv = getRegister(reg.*, iss.sas);
            vm.current().mmioWrite(fipa, regv);
        },
    }

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

/// Get register value with specified width.
fn getRegister(reg: u64, sas: @FieldType(regs.Esr.IssDabort, "sas")) mmio.Register {
    return switch (sas) {
        .byte => mmio.Register{ .byte = @truncate(reg) },
        .halfword => mmio.Register{ .hword = @truncate(reg) },
        .word => mmio.Register{ .word = @truncate(reg) },
        .doubleword => mmio.Register{ .dword = reg },
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
const vm = hugin.vm;

const am = @import("asm.zig");
const gicv3 = @import("gicv3.zig");
const paging = @import("paging.zig");
const regs = @import("registers.zig");
const Context = regs.Context;
