var serial: Pl011 = undefined;
var initialized: bool = false;
var lock: SpinLock = .{};

/// Initialize the default serial console.
pub fn init(pl011: Pl011) void {
    serial = pl011;
    initialized = true;
}

/// Enable interrupt.
pub fn enableIntr(id: hugin.intr.IntrId) hugin.intr.IntrError!void {
    hugin.rtt.expect(initialized);

    const ie = lock.lockDisableIrq();
    defer lock.unlockRestoreIrq(ie);

    // Enable GIC interrupt for PL011.
    try hugin.intr.enable(id, .spi, &handler);

    // Enable PL011 interrupt.
    serial.enableIntr();
}

/// Check if the default serial console is initialized.
pub fn isInitialized() bool {
    const ie = lock.lockDisableIrq();
    defer lock.unlockRestoreIrq(ie);

    return initialized;
}

/// Write a single byte to the default serial console.
pub fn write(c: u8) void {
    serial.putc(c);
}

/// Write a string to the default serial console.
pub fn writeString(s: []const u8) void {
    const ie = lock.lockDisableIrq();
    defer lock.unlockRestoreIrq(ie);

    for (s) |c| {
        write(c);
    }
}

/// IRQ handler for serial device.
fn handler(_: *hugin.arch.Context) bool {
    if (serial.getc()) |c| {
        // Handle input if a console is active.
        if (hugin.put2console(c)) {
            return true;
        } else {
            // If console is not active, inject it to the VM's UART.
            const current = hugin.vm.current();
            current.uart.putc(c, current.gicdist);
        }
    }

    return true;
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");

const hugin = @import("hugin");
const Pl011 = hugin.drivers.Pl011;
const SpinLock = hugin.SpinLock;
