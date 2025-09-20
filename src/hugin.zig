pub const arch = @import("arch.zig").impl;
pub const bits = @import("bits.zig");
pub const drivers = @import("drivers.zig");
pub const dtb = @import("dtb.zig");
pub const klog = @import("klog.zig");
pub const serial = @import("serial.zig");

/// Git SHA of Hugin kernel.
pub const sha = options.sha;

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
