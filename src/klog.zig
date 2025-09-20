/// Logger function type
pub const LogFn = *const fn (comptime format: []const u8, args: anytype) void;

/// Log level.
///
/// Can be configured by compile-time options. See build.zig.
pub const log_level = switch (options.log_level) {
    .debug => .debug,
    .info => .info,
    .warn => .warn,
    .err => .err,
};

const writer_vtable = std.Io.Writer.VTable{
    .drain = drain,
};

var writer = std.Io.Writer{
    .vtable = &writer_vtable,
    .buffer = &.{},
};

/// Write data to the serial console.
fn drain(_: *std.Io.Writer, data: []const []const u8, _: usize) !usize {
    var written: usize = 0;
    for (data) |bytes| {
        serial.writeString(bytes);
        written += bytes.len;
    }
    return written;
}

/// Log implementation.
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
) void {
    const level_str = comptime switch (level) {
        .debug => "[DEBUG]",
        .info => "[INFO ]",
        .warn => "[WARN ]",
        .err => "[ERROR]",
    };

    const scope_str = if (@tagName(scope).len <= 8) b: {
        break :b std.fmt.comptimePrint(
            "{s: <8}| ",
            .{@tagName(scope)},
        );
    } else b: {
        break :b std.fmt.comptimePrint(
            "{s: <7}-| ",
            .{@tagName(scope)[0..7]},
        );
    };

    writer.print(
        level_str ++ " " ++ scope_str ++ fmt ++ "\n",
        args,
    ) catch {};
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const io = std.io;
const options = @import("options");
const hugin = @import("hugin");
const serial = hugin.serial;
