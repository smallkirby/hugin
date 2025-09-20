pub const arch = @import("arch.zig").impl;
pub const bits = @import("bits.zig");
pub const drivers = @import("drivers.zig");
pub const dtb = @import("dtb.zig");
pub const klog = @import("klog.zig");
pub const serial = @import("serial.zig");

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

/// Halt the CPU indefinitely.
pub fn endlessHalt() noreturn {
    // TODO: disable IRD
    while (true) {
        arch.halt();
    }
}

// =============================================================
// Tests
// =============================================================

test {
    _ = dtb;
}

// =============================================================
// Imports
// =============================================================

const options = @import("options");
