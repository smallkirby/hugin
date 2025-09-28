//! PrimeCell UART PL011 driver.
//!
//! ref: https://developer.arm.com/documentation/ddi0183/g

const Self = @This();

/// Base address of the UART registers.
base: usize,

const map = struct {
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

/// Control Register.
const Control = packed struct(u16) {
    /// UART enable.
    uarten: bool,
    /// SIR enable.
    siren: bool,
    /// SIR low-power IrDA mode.
    sirlp: bool,
    /// Reserved.
    _reserved: u4 = 0,
    /// Loopback enable.
    lbe: bool,
    /// Transmit enable.
    txe: bool,
    /// Receive enable.
    rxe: bool,
    /// Data transmit ready.
    dtr: bool,
    /// Request to send.
    rts: bool,
    /// Complement of the UART Out1 modem status output.
    out1: bool,
    /// Complement of the UART Out2 modem status output.
    out2: bool,
    /// RTS hardware flow control enable.
    rtsen: bool,
    /// CTS hardware flow control enable.
    ctsen: bool,
};

/// Interrupt Mask Set/Clear Register.
const Imsc = packed struct(u16) {
    /// nUARTRI modem interrupt mask.
    rimim: bool,
    /// nUARTCTS modem interrupt mask.
    ctsmim: bool,
    /// nUARTDCD modem interrupt mask.
    dcdmim: bool,
    /// nUARTDSR modem interrupt mask.
    dsrmim: bool,
    /// Receive interrupt mask.
    rxim: bool,
    /// Transmit interrupt mask.
    txim: bool,
    /// Receive timeout interrupt mask.
    rtim: bool,
    /// Framing error interrupt mask.
    feim: bool,
    /// Parity error interrupt mask.
    peim: bool,
    /// Break error interrupt mask.
    beim: bool,
    /// Overrun error interrupt mask.
    oeim: bool,
    /// Reserved.
    _reserved: u5 = 0,
};

pub fn new(base: usize) Self {
    return Self{ .base = base };
}

/// Enable receive interrupt.
pub fn enableIntr(self: Self) void {
    self.write(map.cr, std.mem.zeroInit(Control, .{
        .uarten = true,
        .txe = true,
        .rxe = true,
    }));
    self.write(map.imsc, std.mem.zeroInit(Imsc, .{
        .rxim = true,
    }));
}

/// Check if the transmit FIFO is full.
fn isTxFull(self: Self) bool {
    return self.read(map.fr, Flag).txff;
}

/// Check if the receive FIFO is empty.
fn isRxEmpty(self: Self) bool {
    return self.read(map.fr, Flag).rxfe;
}

/// Send a character.
///
/// This function blocks until the character is sent.
pub fn putc(self: Self, c: u8) void {
    while (self.isTxFull()) {
        atomic.spinLoopHint();
    }
    self.write(map.dr, c);
}

/// Get a character.
///
/// This function returns null if the receive FIFO is empty.
pub fn getc(self: Self) ?u8 {
    return if (self.isRxEmpty()) null else self.read(map.dr, u8);
}

/// Read from a register.
fn read(self: Self, offset: usize, T: type) T {
    return @bitCast(switch (@bitSizeOf(T)) {
        8 => @as(*volatile u8, @ptrFromInt(self.base + offset)).*,
        16 => @as(*volatile u16, @ptrFromInt(self.base + offset)).*,
        else => @compileError("Pl011.read: Invalid register size"),
    });
}

/// Write to a register.
fn write(self: Self, offset: usize, value: anytype) void {
    switch (@bitSizeOf(@TypeOf(value))) {
        8 => @as(*volatile u8, @ptrFromInt(self.base + offset)).* = @bitCast(value),
        16 => @as(*volatile u16, @ptrFromInt(self.base + offset)).* = @bitCast(value),
        else => @compileError("Pl011.write: Invalid register size"),
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const atomic = std.atomic;
