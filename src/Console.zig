pub const Console = Self;
const Self = @This();

/// Key code to switch to console input mode.
pub const key_to_switch = 0x13; // Ctrl+S

/// Input buffer.
buffer: [size_buffer]u8,
/// Index to next write position.
index: usize = 0,

/// Size in bytes of input buffer.
const size_buffer = 64;

/// Available commands.
const commands = CommandMap.initComptime([_]struct { []const u8, Command }{
    .{ "echo", echo },
    .{ "poweroff", poweroff },
});

/// Command list type.
const CommandMap = std.StaticStringMap(Command);

/// Command handler type.
const Command = *const fn (*SplitIterator) void;

/// Create a new console instance.
pub fn init() Self {
    return .{
        .buffer = undefined,
    };
}

/// Switch to console input mode.
pub fn activate(self: *Self) void {
    prompt(self);
}

/// Switch from console input mode to normal mode.
pub fn deactivate(self: *Self) void {
    self.reset();
    hugin.serial.writeString("\n");
}

/// Write a single character to the console.
pub fn write(self: *Self, c: u8) void {
    // Run command if newline is received.
    if (c == '\n' or c == '\r') {
        hugin.serial.write('\n');
        self.run();
        self.prompt();
        return;
    }

    // Ignore control characters.
    if (std.ascii.isControl(c)) {
        return;
    }
    // Input buffer full.
    if (self.index >= self.buffer.len) {
        return;
    }

    self.buffer[self.index] = c;
    self.index += 1;
    hugin.serial.write(c);
}

/// Run a command stored in the input buffer, then clear the buffer.
fn run(self: *Self) void {
    defer self.reset();

    // Buffer empty.
    if (self.index == 0) {
        return;
    }

    // Run the command.
    var iter = std.mem.splitAny(
        u8,
        self.buffer[0..self.index],
        " ",
    );
    const scmd = iter.next() orelse return;

    const cmd = commands.get(trim(scmd)) orelse {
        hugin.serial.writeString("Command not found.\n");
        return;
    };
    cmd(&iter);
}

/// Trim a string.
fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \r\n");
}

/// Print the prompt.
fn prompt(_: *const Self) void {
    hugin.serial.writeString("HUGIN> ");
}

/// Reset the input buffer.
fn reset(self: *Self) void {
    self.index = 0;
    @memset(self.buffer[0..], 0);
}

/// "echo" command.
fn echo(argiter: *SplitIterator) void {
    while (argiter.next()) |arg| {
        hugin.serial.writeString(trim(arg));
        hugin.serial.writeString(" ");
    }
    hugin.serial.writeString("\n");
}

/// "poweroff" command.
fn poweroff(_: *SplitIterator) void {
    hugin.serial.writeString("Powering off...\n");
    hugin.arch.psci.shutdown();
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const SplitIterator = std.mem.SplitIterator(u8, .any);
