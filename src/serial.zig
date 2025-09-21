var serial: Pl011 = undefined;
var initialized: bool = false;

/// Initialize the default serial console.
pub fn init(pl011: Pl011) void {
    serial = pl011;
    initialized = true;
}

/// Check if the default serial console is initialized.
pub fn isInitialized() bool {
    return initialized;
}

/// Write a single byte to the default serial console.
pub fn write(c: u8) void {
    serial.putc(c);
}

/// Write a string to the default serial console.
pub fn writeString(s: []const u8) void {
    for (s) |c| {
        write(c);
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");

const hugin = @import("hugin");
const Pl011 = hugin.drivers.Pl011;
