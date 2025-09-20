//! PrimeCell UART PL011 driver.
//!
//! ref: https://developer.arm.com/documentation/ddi0183/g

const Self = @This();

/// Base address of the UART registers.
base: usize,

const offsets = struct {
    /// Data Register.
    const dr = 0x00;
    /// Receive Status Register / Error Clear Register.
    const rsr_ecr = 0x04;
    /// Flag Register.
    const fr = 0x18;
    /// IrDA Low-Power Counter Register.
    const ilpr = 0x20;
    /// Integer Baud Rate Register.
    const ibrd = 0x24;
    /// Fractional Baud Rate Register.
    const fbrd = 0x28;
    /// Line Control Register.
    const lcr_h = 0x2C;
    /// Control Register.
    const cr = 0x30;
    /// Interrupt FIFO Level Select Register.
    const ifls = 0x34;
    /// Interrupt Mask Set/Clear Register.
    const imsc = 0x38;
    /// Raw Interrupt Status Register.
    const ris = 0x3C;
    /// Masked Interrupt Status Register.
    const mis = 0x40;
    /// Interrupt Clear Register.
    const icr = 0x44;
    /// DMA Control Register.
    const dmacr = 0x48;
};

/// Flag Register.
const Flag = packed struct(u16) {
    /// Clear to send.
    cts: bool,
    /// Data set ready.
    dsr: bool,
    /// Data carrier detect.
    dcd: bool,
    /// Busy.
    busy: bool,
    /// Receive FIFO empty.
    rxfe: bool,
    /// Transmit FIFO full.
    txff: bool,
    /// Receive FIFO full.
    rxff: bool,
    /// Transmit FIFO empty.
    txfe: bool,
    /// Ring indicator.
    ri: bool,
    /// Reserved.
    _reserved: u7 = 0,
};

pub fn new(base: usize) Self {
    return Self{ .base = base };
}

/// Check if the transmit FIFO is full.
pub fn isTxFull(self: Self) bool {
    return @as(*const volatile Flag, @ptrFromInt(self.base + offsets.fr)).txff;
}

/// Send a character.
///
/// This function blocks until the character is sent.
pub fn putc(self: Self, c: u8) void {
    while (self.isTxFull()) {
        atomic.spinLoopHint();
    }
    @as(*volatile u8, @ptrFromInt(self.base + offsets.dr)).* = c;
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const atomic = std.atomic;
