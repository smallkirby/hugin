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
    .{ "boot", boot },
    .{ "switch", switchVm },
});

/// Command list type.
const CommandMap = std.StaticStringMap(Command);

/// Command handler type.
///
/// Returns `true` to close the console after execution.
const Command = *const fn (*SplitIterator) bool;

/// Devicetree blob.
var dtb: hugin.dtb.Dtb = undefined;
/// Fat32 filesystem instance.
var fat: hugin.Fat32 = undefined;

/// Create a new console instance.
pub fn init(dt: hugin.dtb.Dtb, fat32: hugin.Fat32) Self {
    dtb = dt;
    fat = fat32;

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
        self.prompt();
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
        self.prompt();
        return;
    };

    if (cmd(&iter)) {
        hugin.deactivateConsole();
    } else {
        self.prompt();
    }
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
fn echo(argiter: *SplitIterator) bool {
    while (argiter.next()) |arg| {
        hugin.serial.writeString(trim(arg));
        hugin.serial.writeString(" ");
    }
    hugin.serial.writeString("\n");

    return false;
}

/// "poweroff" command.
fn poweroff(_: *SplitIterator) bool {
    hugin.serial.writeString("Powering off...\n");
    hugin.arch.psci.shutdown();

    unreachable;
}

/// "boot" command.
fn boot(_: *SplitIterator) bool {
    launchAvailAp() catch {
        hugin.serial.writeString("Failed to launch an AP.\n");
        return false;
    };

    return true;
}

/// "switch" command.
fn switchVm(argiter: *SplitIterator) bool {
    const sid = argiter.next() orelse {
        hugin.serial.writeString("Usage: switch <vm_id>\n");
        return false;
    };
    const id = std.fmt.parseInt(u32, trim(sid), 0) catch {
        hugin.serial.writeString("Invalid VM ID.\n");
        return false;
    };

    hugin.vm.switchCurrent(id) catch {
        hugin.serial.writeString("Failed to switch VM.\n");
        return false;
    };

    return true;
}

/// Launch an AP that has not been launched yet.
fn launchAvailAp() !void {
    const current_affinity = hugin.arch.am.mrs(.mpidr_el1).packedAffinity();

    var node: ?hugin.dtb.Node = null;
    while (true) {
        node = try dtb.searchNode(
            .{ .name = "cpu" },
            node,
        ) orelse break;
        const reg = try dtb.readRegProp(
            node.?,
            0,
        ) orelse break;

        // Skip the current PE.
        const affinity = reg.addr;
        if (affinity == current_affinity) {
            continue;
        }

        launchAp(affinity) catch continue;
        break;
    }

    hugin.serial.writeString("No available AP found.\n");
}

/// Launch an AP with given affinity.
fn launchAp(affinity: u64) !void {
    const stack_size = 30 * hugin.mem.size_4kib;

    // Allocate stack for the PE.
    const pages = try hugin.mem.page_allocator.allocPages(
        stack_size / hugin.mem.page_size,
    );
    errdefer hugin.mem.page_allocator.freePages(pages);
    const stack_bottom = @intFromPtr(pages.ptr) + pages.len;

    // Launch the PE.
    try hugin.arch.psci.awakePe(
        affinity,
        @intFromPtr(&apEntry),
        stack_bottom,
    );
}

/// Entry point for APs.
fn apEntry() callconv(.naked) noreturn {
    asm volatile (
        \\mov sp, x0
        \\b %[entry]
        :
        : [entry] "i" (@intFromPtr(&apTrampoline)),
    );
}

/// Trampoline function for APs to jump to Zig code.
fn apTrampoline() callconv(.c) noreturn {
    apMain() catch |err| {
        log.err("AP#{X} aborted with error: {t}", .{
            arch.am.mrs(.mpidr_el1).packedAffinity(),
            err,
        });
    };

    hugin.endlessHalt();
}

/// Main function for APs.
fn apMain() !void {
    const affi = hugin.arch.getAffinity();
    log.info("Hello from AP#{X}", .{affi});

    const cel = hugin.arch.getCurrentEl();
    hugin.rtt.expectEqual(2, cel);

    // NOTE: MMU must be enabled to allow unaligned accesses.
    //   We must copy the TTBR from the BSP to enable paging.
    arch.dupPaging();

    // Setup EL2 settings.
    {
        arch.am.msr(.sctlr_el2, std.mem.zeroInit(arch.regs.Sctlr, .{
            .m = true, // enable MMU
            .a = false, // allow unaligned access
            .c = true,
            .i = 1,
        }));
        asm volatile ("isb");
    }

    // Setup interrupts.
    log.debug("Initializing local interrupts...", .{});
    {
        try hugin.intr.initLocal(dtb);
    }

    // Init VM.
    log.debug("Initializing VM...", .{});
    {
        try hugin.vm.init(fat);
        try hugin.vm.current().boot();
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.console);
const hugin = @import("hugin");
const arch = hugin.arch;
const SplitIterator = std.mem.SplitIterator(u8, .any);
