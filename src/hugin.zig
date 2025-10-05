pub const arch = @import("arch.zig").impl;
pub const bitmap = @import("bitmap.zig");
pub const bits = @import("bits.zig");
pub const drivers = @import("drivers.zig");
pub const dtb = @import("dtb.zig");
pub const intr = @import("intr.zig");
pub const klog = @import("klog.zig");
pub const mem = @import("mem.zig");
pub const mmio = @import("mmio.zig");
pub const rtt = @import("rtt.zig");
pub const serial = @import("serial.zig");
pub const vgic = @import("vgic.zig");
pub const vm = @import("vm.zig");

pub const Fat32 = @import("Fat32.zig");
pub const LogFn = klog.LogFn;
pub const SpinLock = @import("SpinLock.zig");

/// Whether the module is built with runtime tests enabled.
pub const is_runtime_test = options.is_runtime_test;
/// Git SHA of Hugin kernel.
pub const sha = options.sha;

/// Print an unimplemented message and halt the CPU indefinitely.
///
/// - `msg`: Message to print.
pub fn unimplemented(comptime msg: ?[]const u8) noreturn {
    @branchHint(.cold);

    serial.writeString("UNIMPLEMENTED: ");
    if (msg) |s| {
        serial.writeString(s);
    }
    serial.writeString("\n");

    endlessHalt();

    unreachable;
}

/// Terminate QEMU.
///
/// Available only for testing.
///
/// - `status`: Exit status. The QEMU process exits with `status << 1`.
pub fn terminateQemu(status: u8) void {
    if (is_runtime_test) {
        switch (@import("builtin").cpu.arch) {
            .aarch64 => {
                const arg: extern struct {
                    v: u64,
                    status: u64,
                } = .{ .v = 0x20026, .status = @as(u64, status) };
                asm volatile (
                    \\mov x0, #0x18
                    \\mov x1, %[arg]
                    \\hlt #0xF000
                    :
                    : [arg] "r" (&arg),
                );
                endlessHalt();
            },
            else => @panic("terminateQemu() is not available on this architecture"),
        }
    }
}

/// Halt the CPU indefinitely.
pub fn endlessHalt() noreturn {
    // TODO: disable IRQ
    while (true) {
        arch.halt();
    }
}

/// Assert at compile time.
pub fn comptimeAssert(cond: bool, comptime msg: []const u8, args: anytype) void {
    if (!cond) {
        @compileError(std.fmt.comptimePrint(msg, args));
    }
}

/// Print a hex dump of the given memory region.
pub fn hexdump(addr: usize, len: usize, logger: anytype) void {
    const bytes: [*]const u8 = @ptrFromInt(addr);
    const per_line = 16;

    if (len % per_line != 0) {
        @panic("hexdump: length must be multiple of 16");
    }

    var i: usize = 0;
    while (i < len) : (i += 16) {
        logger(
            "{X} | {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2}",
            .{ addr + i, bytes[i + 0], bytes[i + 1], bytes[i + 2], bytes[i + 3], bytes[i + 4], bytes[i + 5], bytes[i + 6], bytes[i + 7], bytes[i + 8], bytes[i + 9], bytes[i + 10], bytes[i + 11], bytes[i + 12], bytes[i + 13], bytes[i + 14], bytes[i + 15] },
        );
    }
}

// =============================================================
// Tests
// =============================================================

test {
    _ = bitmap;
    _ = bits;
    _ = dtb;
    _ = mem;
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const options = @import("options");
