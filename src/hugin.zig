pub const arch = @import("arch.zig").impl;
pub const bits = @import("bits.zig");
pub const drivers = @import("drivers.zig");
pub const dtb = @import("dtb.zig");
pub const klog = @import("klog.zig");
pub const mem = @import("mem.zig");
pub const mmio = @import("mmio.zig");
pub const rtt = @import("rtt.zig");
pub const serial = @import("serial.zig");

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

// =============================================================
// Tests
// =============================================================

test {
    _ = bits;
    _ = dtb;
    _ = mem;
}

// =============================================================
// Imports
// =============================================================

const options = @import("options");
