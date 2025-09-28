var serial: Pl011 = undefined;
var initialized: bool = false;

/// Initialize the default serial console.
pub fn init(pl011: Pl011) void {
    serial = pl011;
    initialized = true;
}

/// Enable interrupt.
pub fn enableIntr(id: hugin.intr.IntrId) hugin.intr.IntrError!void {
    hugin.rtt.expect(initialized);

    // Enable GIC interrupt for PL011.
    try hugin.intr.enable(id, .spi, &handler);

    // Enable PL011 interrupt.
    serial.enableIntr();
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

/// IRQ handler for serial device.
fn handler(_: *hugin.arch.Context) void {
    _ = serial.getc();
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");

const hugin = @import("hugin");
const Pl011 = hugin.drivers.Pl011;
