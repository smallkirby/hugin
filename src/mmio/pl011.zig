const Error = mmio.MmioError;

/// PL011 virtual MMIO device.
pub const Device = struct {
    /// Flag register.
    flag: Flag,
    /// Interrupt mask.
    mask: u16,
    /// Control register.
    ctl: Control,
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
    pub fn new(allocator: Allocator) Error!*Device {
        const self = try allocator.create(Device);
        self.* = .{
            .flag = std.mem.zeroInit(Flag, .{}),
            .mask = 0,
            .ctl = std.mem.zeroInit(Control, .{}),
            .rxbuf = undefined,
            .interface = initInterface(self),
        };

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

                break :blk Register{ .byte = ret };
            },
            map.fr => Register{ .hword = @bitCast(self.flag) },
            map.cr => Register{ .hword = @bitCast(self.ctl) },
            map.imsc => Register{ .hword = self.mask },

            else => Error.Unimplemented,
        };
    }

    /// MMIO write handler.
    pub fn write(ctx: *anyopaque, offset: usize, value: Register) Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        switch (offset) {
            map.dr => hugin.serial.write(value.byte),
            map.cr => self.ctl = @bitCast(value.hword),
            map.imsc => self.mask = @intCast(value.hword),

            else => return Error.Unimplemented,
        }
    }

    /// Get the MMIO device interface.
    pub fn initInterface(self: *Device) vm.MmioDevice {
        return .{
            .ctx = @ptrCast(self),
            .base = 0x9_000_000, // TODO
            .len = 0x1000, // TODO
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

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const mmio = hugin.mmio;
const vm = hugin.vm;
const Allocator = std.mem.Allocator;
