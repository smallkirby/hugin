pub fn eret() noreturn {
    asm volatile ("eret");
    unreachable;
}

pub fn mrs(comptime reg: SystemReg) SystemReg.Type(reg) {
    return @bitCast(asm volatile (std.fmt.comptimePrint(
            \\mrs %[ret], {s}
        , .{reg.str()})
        : [ret] "=r" (-> switch (@sizeOf(SystemReg.Type(reg))) {
            4 => u32,
            8 => u64,
            else => @compileError("Unsupported system register size."),
          }),
    ));
}

pub fn msr(comptime reg: SystemReg, value: SystemReg.Type(reg)) void {
    asm volatile (std.fmt.comptimePrint(
            \\msr {s}, %[value]
        , .{reg.str()})
        :
        : [value] "r" (@as(switch (@sizeOf(SystemReg.Type(reg))) {
            4 => u32,
            8 => u64,
            else => @compileError("Unsupported system register size."),
          }, @bitCast(value))),
    );
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const regs = @import("registers.zig");
const SystemReg = regs.SystemReg;
