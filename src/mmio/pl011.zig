const Reg = struct {
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

pub fn read(offset: usize) mmio.MmioError!u64 {
    switch (offset) {
        Reg.fr => return 0,

        else => return mmio.MmioError.Unimplemented,
    }
}

pub fn write(offset: usize, value: u64) mmio.MmioError!void {
    switch (offset) {
        Reg.dr => hugin.serial.write(@truncate(value)),

        else => return mmio.MmioError.Unimplemented,
    }
}

// =============================================================
// Imports
// =============================================================

const hugin = @import("hugin");
const mmio = hugin.mmio;
