/// Convert from big-endian to native-endian
pub fn fromBigEndian(value: anytype) @TypeOf(value) {
    if (builtin.cpu.arch.endian() == .big) {
        return value;
    } else {
        return @byteSwap(value);
    }
}

/// Convert from native-endian to big-endian
pub fn toBigEndian(value: anytype) @TypeOf(value) {
    return fromBigEndian(value);
}

/// Round up the value to the given alignment.
///
/// If the type of `value` is a comptime integer, it's regarded as `usize`.
pub inline fn roundup(value: anytype, alignment: @TypeOf(value)) @TypeOf(value) {
    const T = if (@typeInfo(@TypeOf(value)) == .comptime_int) usize else @TypeOf(value);
    return (value + alignment - 1) & ~@as(T, alignment - 1);
}

/// Round down the value to the given alignment.
///
/// If the type of `value` is a comptime integer, it's regarded as `usize`.
pub inline fn rounddown(value: anytype, alignment: @TypeOf(value)) @TypeOf(value) {
    const T = if (@typeInfo(@TypeOf(value)) == .comptime_int) usize else @TypeOf(value);
    return value & ~@as(T, alignment - 1);
}

// =============================================================
// Imports
// =============================================================

const builtin = @import("builtin");
