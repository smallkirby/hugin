const Error = mmio.MmioError;

/// Interrupt ID for PL011.
const intid_pl011 = 33;

/// PL011 virtual MMIO device.
pub const Device = struct {
    /// Flag register.
    flag: Flag,
    /// Interrupt mask.
    mask: Imsc,
    /// Control register.
    ctl: Control,
    /// Interrupt clear status.
    icr: Icr,
    /// Receive FIFO.
    rxbuf: [4]u8,
    /// MMIO device interface.
    interface: vm.MmioDevice,

    const Self = @This();
    const Register = mmio.Register;

    const handler = vm.MmioDevice.Handler{
        .read = &read,
        .write = &write,
    };

    /// Create a new PL011 device instance.
    pub fn new(allocator: Allocator, base: usize, len: usize) Error!*Device {
        const self = try allocator.create(Device);
        self.* = std.mem.zeroInit(Self, .{
            .interface = initInterface(self, base, len),
        });

        return self;
    }

    /// MMIO read handler.
    pub fn read(ctx: *anyopaque, offset: usize, _: mmio.Width) Error!Register {
        const self: *Self = @ptrCast(@alignCast(ctx));

        return switch (offset) {
            map.dr => blk: {
                const ret = self.rxbuf[0];
                self.flag.rxfe = true;

                // Shift the FIFO.
                for (1..self.rxbuf.len) |i| {
                    self.rxbuf[i - 1] = self.rxbuf[i];
                }
                if (self.rxbuf[0] == 0) {
                    self.flag.rxfe = true;
                    self.icr.rxic = false;
                }

                break :blk Register{ .byte = ret };
            },
            map.fr => Register{ .hword = @bitCast(self.flag) },
            map.cr => Register{ .hword = @bitCast(self.ctl) },
            map.imsc => Register{ .hword = @bitCast(self.mask) },
            map.ris => Register{ .hword = @bitCast(self.icr) },

            map.periph_id0 => Register{ .byte = 0x11 },
            map.periph_id1 => Register{ .byte = 0x10 },
            map.periph_id2 => Register{ .byte = 0x04 },
            map.periph_id3 => Register{ .byte = 0x00 },
            map.pcell_id0 => Register{ .byte = 0x0D },
            map.pcell_id1 => Register{ .byte = 0xF0 },
            map.pcell_id2 => Register{ .byte = 0x05 },
            map.pcell_id3 => Register{ .byte = 0xB1 },

            else => {
                log.err("Unhandled PL011 read @ 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        };
    }

    /// MMIO write handler.
    pub fn write(ctx: *anyopaque, offset: usize, value: Register) Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        switch (offset) {
            map.dr => switch (value) {
                .byte => hugin.serial.write(value.byte),
                // When FIFOs are enabled, 4-bit status + 8-bit data are written.
                .hword => hugin.serial.write(@truncate(value.hword)),
                else => unreachable,
            },
            map.ibrd => {},
            map.fbrd => {},
            map.lcr_h => {},
            map.cr => self.ctl = @bitCast(value.hword),
            map.ifls => {},
            map.imsc => self.mask = @bitCast(value.hword),
            map.icr => {
                const val: u16 = @bitCast(value.hword);
                const icr: u16 = @bitCast(self.icr);
                self.icr = @bitCast(icr & ~val);
            },

            else => {
                log.err("Unhandled PL011 write @ 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        }
    }

    /// Put a character to the receive FIFO and trigger interrupt if enabled.
    pub fn putc(self: *Self, c: u8, dist: *mmio.gicv3.DistributorDevice) void {
        for (&self.rxbuf) |*b| {
            if (b.* == 0) {
                b.* = c;
                break;
            }
        }
        self.flag.rxfe = false;

        if (self.mask.rxim) {
            self.icr.rxic = true;
            dist.inject(intid_pl011, null);
        }
    }

    /// Get the MMIO device interface.
    fn initInterface(self: *Device, base: usize, len: usize) vm.MmioDevice {
        return .{
            .ctx = @ptrCast(self),
            .base = base,
            .len = len,
            .handler = handler,
        };
    }
};

/// Register map.
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

    /// UARTPeriphID0.
    const periph_id0 = 0xFE0;
    /// UARTPeriphID1.
    const periph_id1 = 0xFE4;
    /// UARTPeriphID2.
    const periph_id2 = 0xFE8;
    /// UARTPeriphID3.
    const periph_id3 = 0xFEC;
    /// UARTPCellID0.
    const pcell_id0 = 0xFF0;
    /// UARTPCellID1.
    const pcell_id1 = 0xFF4;
    /// UARTPCellID2.
    const pcell_id2 = 0xFF8;
    /// UARTPCellID3.
    const pcell_id3 = 0xFFC;
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

/// UARTICR.
///
/// Interrupt clear register and is write-only.
/// On a write of 1, the corresponding interrupt is cleared.
const Icr = packed struct(u16) {
    /// Clear UARTRIINTR.
    rimic: bool,
    /// Clear UARTCTSINTR.
    ctsmic: bool,
    /// Clear UARTDCDINTR.
    dcdmic: bool,
    /// Clear UARTDSRINTR.
    dsrmic: bool,
    /// Clear UARTRXINTR.
    rxic: bool,
    /// Clear UARTTXINTR.
    txic: bool,
    /// Clear UARTRTINTR.
    rtic: bool,
    /// Clear UARTFEINTR.
    feic: bool,
    /// Clear UARTPEINTR.
    peic: bool,
    /// Clear UARTBEINTR.
    beic: bool,
    /// Clear UARTOEINTR.
    oeic: bool,
    /// Reserved.
    _reserved: u5 = 0,
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

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.vpl011);
const hugin = @import("hugin");
const mmio = hugin.mmio;
const vm = hugin.vm;
const Allocator = std.mem.Allocator;
