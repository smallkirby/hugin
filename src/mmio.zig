pub const MmioError = error{
    /// Feature is not implemented.
    Unimplemented,
};

/// Access width.
pub const Width = enum {
    byte,
    hword,
    word,
    dword,

    pub fn IntType(self: Width) type {
        return switch (self) {
            .byte => u8,
            .hword => u16,
            .word => u32,
            .dword => u64,
        };
    }
};

pub fn read(address: usize, reg: *u64, width: Width) MmioError!void {
    const pl001_base = 0x9_000_000;

    if (pl001_base <= address and address < pl001_base + 0x1000) {
        const offset = address - pl001_base;
        const value = try pl001.read(offset);
        set(reg, value, width);

        return;
    }

    return MmioError.Unimplemented;
}

pub fn write(address: usize, reg: *u64, width: Width) MmioError!void {
    _ = width;

    const pl001_base = 0x9_000_000;

    if (pl001_base <= address and address < pl001_base + 0x1000) {
        const offset = address - pl001_base;
        try pl001.write(offset, reg.*);

        return;
    }

    return MmioError.Unimplemented;
}

fn set(reg: *u64, value: anytype, width: Width) void {
    switch (width) {
        .byte => @as(*u8, @ptrCast(reg)).* = @truncate(value),
        .hword => @as(*u16, @ptrCast(reg)).* = @truncate(value),
        .word => @as(*u32, @ptrCast(reg)).* = @truncate(value),
        .dword => @as(*u64, @ptrCast(reg)).* = @truncate(value),
    }
}

// =============================================================
// Imports
// =============================================================

const pl001 = @import("mmio/pl011.zig");
