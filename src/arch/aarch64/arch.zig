pub const am = @import("asm.zig"); // TODO: should not be exported.
pub const regs = @import("registers.zig"); // TODO: should not be exported.

/// Halt until interrupt.
pub fn halt() void {
    asm volatile ("wfi");
}

/// Get the current exception level.
pub fn getCurrentEl() u2 {
    return am.mrs(.current_el).el;
}

/// Get the current SP.
pub inline fn getSp() usize {
    return asm volatile (
        \\mov %[sp], sp
        : [sp] "=r" (-> usize),
    );
}
