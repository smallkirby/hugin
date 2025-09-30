pub const Error = error{
    /// Memory allocation failed.
    OutOfMemory,
    /// No available bits.
    Full,
    /// Invalid argument.
    InvalidArgument,
};

pub fn Bitmap(size: usize) type {
    return struct {
        const Self = @This();

        /// Number of bytes required to store `size` bits.
        const num_bytes = bits.roundup(size, 8) / 8;
        /// Unit type.
        const Unit = u8;

        /// Bitmap data.
        _data: []Unit,

        pub fn init(allocator: Allocator) Allocator.Error!Self {
            const data = try allocator.alloc(Unit, num_bytes);
            @memset(data, 0);

            return Self{
                ._data = data,
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self._data);
        }

        pub fn alloc(self: *Self) Error!usize {
            for (self._data, 0..) |*b, i| {
                for (0..@bitSizeOf(Unit)) |j| {
                    if (!bits.isset(b.*, j)) {
                        const index = i * @bitSizeOf(Unit) + j;
                        if (index >= size) {
                            return Error.Full;
                        }

                        b.* = bits.set(b.*, j);
                        return index;
                    }
                }
            }
            return Error.Full;
        }

        pub fn free(self: *Self, index: usize) Error!void {
            if (index >= size) {
                return Error.InvalidArgument;
            }
            const byte_index = index / @bitSizeOf(Unit);
            const bit_index = index % @bitSizeOf(Unit);
            self._data[byte_index] = bits.unset(self._data[byte_index], bit_index);
        }
    };
}

// =============================================================
// Tests
// =============================================================

const testing = std.testing;

test Bitmap {
    const allocator = testing.allocator;
    const B = Bitmap(20);
    var bitmap = try B.init(allocator);
    defer bitmap.deinit(allocator);

    for (0..20) |idx| {
        const i = try bitmap.alloc();
        try testing.expectEqual(idx, i);
    }
    try testing.expectError(Error.Full, bitmap.alloc());

    for (0..20) |idx| {
        try bitmap.free(idx);
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const Allocator = std.mem.Allocator;

const hugin = @import("hugin");
const bits = hugin.bits;
