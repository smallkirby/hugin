export fn main(argc: usize, argv: [*]const [*:0]const u8) callconv(.c) usize {
    kernelMain(argc, argv) catch |err| {
        return @intFromError(err);
    };

    return 0;
}

fn kernelMain(argc: usize, argv: [*]const [*:0]const u8) !void {
    if (argc != 1) {
        return error.InvalidArgumentCount;
    }

    const arg0 = argv[0];
    const dtb_addr_str = arg0[0..std.mem.len(arg0)];
    const dtb_addr = try std.fmt.parseInt(usize, dtb_addr_str, 0);
    const dtb = try hugin.dtb.Dtb.new(dtb_addr);
    const pl011_node = try dtb.searchNode("arm,pl011", null) orelse {
        return error.SearchPl011Node;
    };
    if (!try dtb.isNodeOperational(pl011_node)) {
        return error.NodeNotOperational;
    }
    const pl011_reg = try dtb.readRegProp(pl011_node, 0) orelse {
        return error.NoRegProperty;
    };
    const uart = hugin.drivers.Pl011.new(pl011_reg.addr);

    for ("Hello, Hugin!\n") |c| {
        uart.putc(c);
    }

    while (true) {
        asm volatile ("wfi");
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
