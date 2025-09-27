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

/// Extract a value of type `T`  from `value` at the specified `offset`.
///
/// - `T`: The type of the value to extract.
/// - `value`: The value to extract from. Can be any type whose size is the power of two and smaller than or equal to 8 bytes.
/// - `offset`: The bit offset to extract the value.
pub fn extract(T: type, value: anytype, comptime offset: usize) T {
    const size_T = @bitSizeOf(T);
    const size_value = @bitSizeOf(@TypeOf(value));

    if (size_T + offset > size_value) {
        @compileError(std.fmt.comptimePrint(
            "extract: offset out of range: {s}, {s}, {d}",
            .{ @typeName(T), @typeName(@TypeOf(value)), offset },
        ));
    }

    const RepV = RepInt(@TypeOf(value));
    const RepT = RepInt(T);

    const rep_value: RepV = @bitCast(value);
    const t: RepT = @truncate(rep_value >> offset);
    return @bitCast(t);
}

/// Concatnate two values and returns new value with twice the bit width.
///
/// - `T` : Type of the output value.
/// - `a` : The first value. Becomes the upper half of the output.
/// - `b` : The second value. Must be the same type as `a`. Becomes the lower half of the output.
pub inline fn concat(T: type, a: anytype, b: @TypeOf(a)) T {
    const U = @TypeOf(a);
    const width_T = @typeInfo(T).int.bits;
    const width_U = switch (@typeInfo(U)) {
        .int => |t| t.bits,
        .comptime_int => width_T / 2,
        else => @compileError("concat: invalid type"),
    };
    if (width_T != width_U * 2) @compileError("concat: invalid type");
    return (@as(T, a) << width_U) | @as(T, b);
}

/// Concatnate two values and returns new value of type `T`.
///
/// - `T` : Type of the output value.
/// - `a` : The first value. Becomes the upper part of the output.
/// - `b` : The second value.
pub inline fn concatAny(T: type, a: anytype, b: @TypeOf(a)) T {
    const U = @TypeOf(b);
    const width_U = @typeInfo(U).int.bits;

    return (@as(T, a) << width_U) | @as(T, b);
}

/// Embed a `value` into `n` at the specified `offset`.
///
/// - `n`: The original integer.
/// - `value`: The value to embed. Can be any type whose size is the power of two and smaller than or equal to 8 bytes.
/// - `offset`: The bit offset to embed the value.
pub fn embed(n: anytype, value: anytype, comptime offset: usize) @TypeOf(n) {
    const size_n = @bitSizeOf(@TypeOf(n));
    const size_value = @bitSizeOf(@TypeOf(value));

    if (size_value + offset > size_n) {
        @compileError(std.fmt.comptimePrint(
            "embed: offset out of range: {s}, {s}, {d}",
            .{ @typeName(@TypeOf(n)), @typeName(@TypeOf(value)), offset },
        ));
    }

    const N = @TypeOf(n);
    const V = @TypeOf(value);
    const RepN = RepInt(N);
    const RepV = RepInt(V);

    var result: RepN = @bitCast(n);
    const rep_value: RepV = @bitCast(value);

    result &= ~@as(RepN, std.math.maxInt(RepV) << offset);
    result |= @as(RepN, rep_value) << offset;
    return @bitCast(result);
}

/// Set the nth bit.
///
/// - `val` : The integer to modify.
/// - `nth` : The bit position to set.
pub fn set(val: anytype, nth: anytype) @TypeOf(val) {
    const int_nth = switch (@typeInfo(@TypeOf(nth))) {
        .int, .comptime_int => nth,
        .@"enum" => @intFromEnum(nth),
        else => @compileError("isset: invalid type"),
    };
    return val | (@as(@TypeOf(val), 1) << @intCast(int_nth));
}

/// Unset the nth bit.
///
/// - `val` : The integer to modify.
/// - `nth` : The bit position to unset.
pub fn unset(val: anytype, nth: anytype) @TypeOf(val) {
    const int_nth = switch (@typeInfo(@TypeOf(nth))) {
        .int, .comptime_int => nth,
        .@"enum" => @intFromEnum(nth),
        else => @compileError("isset: invalid type"),
    };
    return val & ~(@as(@TypeOf(val), 1) << @intCast(int_nth));
}

/// Check if the nth bit is set.
///
/// - `val` : The integer to check.
/// - `nth` : The bit position to check.
pub fn isset(val: anytype, nth: anytype) bool {
    const int_nth = switch (@typeInfo(@TypeOf(nth))) {
        .int, .comptime_int => nth,
        .@"enum" => @intFromEnum(nth),
        else => @compileError("isset: invalid type"),
    };
    return ((val >> @intCast(int_nth)) & 1) != 0;
}

/// Get the representative integer type.
fn RepInt(T: type) type {
    return switch (@sizeOf(T)) {
        1 => u8,
        2 => u16,
        4 => u32,
        8 => u64,
        else => @compileError(std.fmt.comptimePrint(
            "Invalid argument to RepInt: {s}",
            .{@typeName(T)},
        )),
    };
}

// =============================================================
// Tests
// =============================================================

const testing = std.testing;

test "concat" {
    try testing.expectEqual(0b10, concat(u2, @as(u1, 1), @as(u1, 0)));
    try testing.expectEqual(0x1234, concat(u16, 0x12, 0x34));
}

test "extract" {
    const S = packed struct(u64) {
        a: u8,
        b: u8,
        c: u16,
        d: u32,
    };
    const s = S{ .a = 0x12, .b = 0x21, .c = 0x3456, .d = 0x789ABCDE };

    try testing.expectEqual(@as(u8, 0x12), extract(u8, s, 0));
    try testing.expectEqual(@as(u8, 0x21), extract(u8, s, 8));
    try testing.expectEqual(@as(u16, 0x3456), extract(u16, s, 16));
    try testing.expectEqual(@as(u32, 0x789ABCDE), extract(u32, s, 32));
}

test "set" {
    try testing.expectEqual(0b11, set(0b01, 1));
    try testing.expectEqual(0b101, set(0b001, 2));
    try testing.expectEqual(0b1000_0000, set(0b0000_0000, 7));
}

test "unset" {
    try testing.expectEqual(0b01, unset(@as(u32, 0b11), 1));
    try testing.expectEqual(0b001, unset(@as(u32, 0b101), 2));
    try testing.expectEqual(0b101, unset(@as(u32, 0b101), 1));
    try testing.expectEqual(0b0000_0000, unset(@as(u32, 0b1000_0000), 7));
}

test "isset" {
    try testing.expectEqual(true, isset(0b10, 1));
    try testing.expectEqual(false, isset(0b10, 0));
    try testing.expectEqual(true, isset(0b1000_0000, 7));
    try testing.expectEqual(false, isset(0b1000_0000, 99));
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const builtin = @import("builtin");
