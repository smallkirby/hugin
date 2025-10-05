pub const gicv3 = @import("mmio/gicv3.zig");
pub const pl001 = @import("mmio/pl011.zig");

pub const MmioError = error{
    /// Memory allocation failed.
    OutOfMemory,
    /// Read or write access with invalid width.
    InvalidWidth,
    /// Feature is not implemented.
    Unimplemented,
};

/// Access width.
pub const Width = enum {
    byte,
    hword,
    word,
    dword,
};

/// Register value type.
pub const Register = union(Width) {
    byte: u8,
    hword: u16,
    word: u32,
    dword: u64,
};
