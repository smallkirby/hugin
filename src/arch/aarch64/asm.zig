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

pub fn smc(arg0: u64, arg1: u64, arg2: u64, arg3: u64) u64 {
    return asm volatile (
        \\mov x0, %[x0]
        \\mov x1, %[x1]
        \\mov x2, %[x2]
        \\mov x3, %[x3]
        \\smc #0
        : [ret] "={x0}" (-> u64),
        : [x0] "r" (arg0),
          [x1] "r" (arg1),
          [x2] "r" (arg2),
          [x3] "r" (arg3),
        : .{
          .x4 = true,
          .x5 = true,
          .x6 = true,
          .x7 = true,
          .x8 = true,
          .x9 = true,
          .x10 = true,
          .x11 = true,
          .x12 = true,
          .x13 = true,
          .x14 = true,
          .memory = true,
        });
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const regs = @import("registers.zig");
const SystemReg = regs.SystemReg;
