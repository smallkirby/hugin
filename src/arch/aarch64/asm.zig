pub fn eret() noreturn {
    asm volatile ("eret");
    unreachable;
}

pub fn mrs(comptime reg: SystemReg) SystemReg.Type(reg) {
    return @bitCast(asm volatile (std.fmt.comptimePrint(
            \\mrs %[ret], {s}
        , .{reg.str()})
        : [ret] "=r" (-> u64),
    ));
}

pub fn msr(comptime reg: SystemReg, value: SystemReg.Type(reg)) void {
    asm volatile (std.fmt.comptimePrint(
            \\msr {s}, %[value]
        , .{reg.str()})
        :
        : [value] "r" (@as(u64, @bitCast(value))),
    );
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const regs = @import("registers.zig");
const SystemReg = regs.SystemReg;
