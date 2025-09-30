//! Flattened Devicetree Format (DTB) v0.4.
//!
//! ref: https://github.com/devicetree-org/devicetree-specification/tree/v0.4

pub const DtbError = error{
    /// Header is invalid.
    InvalidHeader,
    /// The DTB version is unsupported.
    UnsupportedVersion,
    /// Reached the end of the data.
    UnexpectedEof,
    /// Reached the unexpected token.
    UnexpectedToken,
};

pub const SearchOption = union(enum) {
    /// Find by `compatible` property.
    compat: []const u8,
    /// Find by node name.
    name: []const u8,
};

/// Flattened Devicetree Blob.
pub const Dtb = struct {
    /// Pointer to the FDT header.
    header: *const FdtHeader,

    const magic: u32 = 0xD00DFEED;
    const version: u32 = 17;

    /// Create new DTB instance and verify the header.
    pub fn new(addr: usize) DtbError!Dtb {
        const header: *const FdtHeader = @ptrFromInt(addr);

        if (bits.fromBigEndian(header.magic) != magic) {
            return DtbError.InvalidHeader;
        }
        if (bits.fromBigEndian(header.version) > version) {
            return DtbError.UnsupportedVersion;
        }

        return Dtb{
            .header = header,
        };
    }

    /// Search for a node with the given compatible string.
    ///
    /// If `current` is not `null`, search starts from the given node.
    pub fn searchNode(self: Dtb, option: SearchOption, current: ?Node) DtbError!?Node {
        var parser = try Parser.new(self.header, current, true);

        while (!parser.isEmpty()) {
            if (try parser.search(option)) |found| {
                return found;
            }
        } else return null;
    }

    /// Read the register value at the given index from the `reg` property of the node.
    pub fn readRegProp(self: Dtb, node: Node, index: usize) DtbError!?hugin.mem.PhysRegion {
        var parser = try Parser.new(self.header, node, false);
        const reg = try parser.getProp("reg") orelse return null;

        const offset = (reg.addr_cells + reg.size_cells) * @sizeOf(u32) * index;
        if (offset + (reg.addr_cells + reg.size_cells) * @sizeOf(u32) > reg.len) {
            return null;
        }

        const addr_offset = offset;
        var addr: usize = 0;
        for (0..reg.addr_cells * @sizeOf(u32)) |i| {
            addr <<= @bitSizeOf(u8);
            addr |= @as(*const u8, @ptrFromInt(reg.addr + addr_offset + i)).*;
        }

        const size_offset = offset + reg.addr_cells * @sizeOf(u32);
        var size: usize = 0;
        for (0..reg.size_cells * @sizeOf(u32)) |i| {
            size <<= @bitSizeOf(u8);
            size |= @as(*const u8, @ptrFromInt(reg.addr + size_offset + i)).*;
        }

        return .{ .addr = addr, .size = size };
    }

    /// Get a property value by name within the given node.
    pub fn getProp(self: Dtb, node: Node, name: []const u8) DtbError!?Property {
        var parser = try Parser.new(self.header, node, false);
        return try parser.getProp(name);
    }

    /// Check if the node is marked as "okay" in the `status` property.
    pub fn isNodeOperational(self: *const Dtb, node: Node) DtbError!bool {
        var parser = try Parser.new(self.header, node, false);
        const status = try parser.getProp("status") orelse return true;

        var iter = Parser.StringIter.new(status.addr, status.len);
        while (iter.next()) |s| {
            if (std.mem.eql(u8, s, "okay")) {
                return true;
            }
        }
        return false;
    }

    /// Get the total size of the DTB in bytes.
    pub fn getSize(self: Dtb) usize {
        return bits.fromBigEndian(self.header.total_size);
    }

    /// Get the address of the DTB.
    pub fn address(self: Dtb) usize {
        return @intFromPtr(self.header);
    }
};

const Parser = struct {
    header: *const FdtHeader,
    ptr: usize,
    state: State,

    const default_addr_cells: u32 = 2;
    const default_size_cells: u32 = 1;

    const Chunk = [token_align]u8;
    /// Alignment for structure block tokens.
    const token_align: usize = 0x4;

    /// Parser state for the current node.
    const State = struct {
        addr_cells: u32 = default_addr_cells,
        size_cells: u32 = default_size_cells,
    };

    // Predefined property names.
    const prop_addr_cells = "#address-cells";
    const prop_size_cells = "#size-cells";
    const prop_compat = "compatible";

    pub fn new(header: *const FdtHeader, current: ?Node, skip: bool) DtbError!Parser {
        if (current) |cur| {
            var parser = Parser{
                .header = header,
                .ptr = cur.addr,
                .state = State{
                    .addr_cells = cur.addr_cells,
                    .size_cells = cur.size_cells,
                },
            };
            if (skip) try parser.skipToNextNode();

            return parser;
        } else {
            return Parser{
                .header = header,
                .ptr = header.structAddr(),
                .state = State{},
            };
        }
    }

    /// Find a node with the given search option.
    ///
    /// This function searches recursively within the first node.
    /// When a matching node is found, the parser state is undefined.
    pub fn search(self: *Parser, option: SearchOption) DtbError!?Node {
        try self.consumeNop();
        if (!Token.eql(.begin_node, try self.consumeChunk())) {
            return error.UnexpectedToken;
        }

        // Compare node name.
        const node_name = try self.consumeString();
        try self.consumePadding();

        if (option == .name) {
            var iter = std.mem.splitAny(u8, node_name, "@");
            while (iter.next()) |part| {
                if (std.mem.eql(u8, part, option.name)) {
                    return Node{
                        .addr = self.ptr,
                        .addr_cells = self.state.addr_cells,
                        .size_cells = self.state.size_cells,
                    };
                }
            }
        }

        // Iterate over properties and child nodes.
        const cur_ptr = self.ptr;
        const cur_state = self.state;
        while (true) {
            try self.consumeNop();

            switch (Token.from(try self.peekChunk())) {
                // Begins new child node.
                .begin_node => if (try self.search(option)) |found| {
                    return found;
                },

                // Property
                .prop => {
                    _ = try self.consumeChunk();

                    const len = try self.consumeU32();
                    const nameoff = try self.consumeU32();
                    const name = self.header.getName(nameoff);

                    // Update address cells.
                    if (std.mem.eql(u8, name, prop_addr_cells)) {
                        self.state.addr_cells = try self.peekU32();
                    }
                    // Update size cells.
                    if (std.mem.eql(u8, name, prop_size_cells)) {
                        self.state.size_cells = try self.peekU32();
                    }

                    // Check compatible string.
                    if ((option == .compat) and std.mem.eql(u8, name, prop_compat)) {
                        var iter = StringIter.new(self.ptr, len);

                        while (iter.next()) |s| {
                            if (std.mem.eql(u8, s, option.compat)) {
                                return Node{
                                    .addr = cur_ptr,
                                    .addr_cells = self.state.addr_cells,
                                    .size_cells = self.state.size_cells,
                                };
                            }
                        }
                    }

                    self.ptr += len;
                },

                // End of the current node.
                .end_node => {
                    _ = try self.consumeChunk();
                    self.state = cur_state;
                    return null;
                },

                // End of data.
                .end => return null,

                // Unhandled tokens.
                else => return error.UnexpectedToken,
            }
        }
    }

    /// Get a property value by name within the current node.
    pub fn getProp(self: *Parser, name: []const u8) DtbError!?Property {
        while (true) {
            try self.consumeNop();

            switch (Token.from(try self.consumeChunk())) {
                // End of the current node.
                .begin_node, .end, .end_node => return null,

                // Property
                .prop => {
                    const len = try self.consumeU32();
                    const nameoff = try self.consumeU32();

                    const prop_name = self.header.getName(nameoff);
                    if (std.mem.eql(u8, prop_name, name)) {
                        return Property{
                            .addr = self.ptr,
                            .addr_cells = self.state.addr_cells,
                            .size_cells = self.state.size_cells,
                            .len = len,
                        };
                    }

                    self.ptr += len;
                },

                // Unhandled tokens.
                else => return error.UnexpectedToken,
            }
        }
    }

    /// Check if the parser reached the end of the data.
    pub fn isEmpty(self: Parser) bool {
        return self.ptr >= self.header.structAddr() + self.header.structSize();
    }

    /// Consume a byte and return it.
    fn consumeByte(self: *Parser) u8 {
        const b = @as(*const u8, @ptrFromInt(self.ptr)).*;
        self.ptr += 1;
        return b;
    }

    /// Peek the current chunk and return it as `u32`.
    fn peekU32(self: *Parser) DtbError!u32 {
        const token = try self.peekChunk();
        return bits.fromBigEndian(@as(*const u32, @ptrCast(@alignCast(&token))).*);
    }

    /// Consume the current chunk and return it as `u32`.
    fn consumeU32(self: *Parser) DtbError!u32 {
        const token = try self.consumeChunk();
        return bits.fromBigEndian(@as(*const u32, @ptrCast(@alignCast(&token))).*);
    }

    /// Read the next 4 bytes.
    ///
    /// Pointer is not advanced.
    fn peekChunk(self: *Parser) DtbError!Chunk {
        if (self.ptr >= self.header.structAddr() + self.header.structSize()) {
            return DtbError.UnexpectedEof;
        } else {
            return @as(*Chunk, @ptrFromInt(self.ptr)).*;
        }
    }

    /// Consume the current chunk and return it.
    fn consumeChunk(self: *Parser) DtbError!Chunk {
        const tok = try self.peekChunk();
        self.ptr += token_align;
        return tok;
    }

    /// Consume a null-terminated string and return it.
    fn consumeString(self: *Parser) DtbError![]const u8 {
        const ptr: [*:0]const u8 = @ptrFromInt(self.ptr);
        const len = std.mem.len(ptr);

        if (self.ptr + len + 1 > self.header.structAddr() + self.header.structSize()) {
            return DtbError.UnexpectedEof;
        }
        self.ptr += len + 1;
        return ptr[0..len];
    }

    /// Skip tokens until a non-nop token is found.
    fn consumeNop(self: *Parser) DtbError!void {
        try self.consumePadding();
        while (Token.eql(.nop, try self.peekChunk())) : (self.ptr += token_align) {}
    }

    /// Discard bytes to the next alignment boundary.
    fn consumePadding(self: *Parser) DtbError!void {
        self.ptr = bits.roundup(self.ptr, token_align);
    }

    /// Skip to the end of the current node.
    fn skipToNextNode(self: *Parser) DtbError!void {
        while (true) {
            try self.consumeNop();

            switch (Token.from(try self.consumeChunk())) {
                // Begins new child node.
                .begin_node => try self.skipToNextNode(),

                // End of the current node.
                .end_node => return,

                // End of data.
                .end => return DtbError.UnexpectedEof,

                // Property
                .prop => {
                    const len = try self.consumeU32();
                    _ = try self.consumeU32(); // nameoff
                    self.ptr += len;
                },

                // Unhandled tokens.
                else => return error.UnexpectedToken,
            }
        }
    }

    /// Iterator over a null-terminated strings.
    const StringIter = struct {
        ptr: [*]const u8,
        cur: [*]const u8,
        end: [*]const u8,

        pub fn new(addr: usize, size: usize) StringIter {
            const ptr: [*]const u8 = @ptrFromInt(addr);
            return StringIter{
                .ptr = ptr,
                .cur = ptr,
                .end = ptr + size,
            };
        }

        pub fn next(self: *StringIter) ?[]const u8 {
            if (@intFromPtr(self.cur) >= @intFromPtr(self.end)) {
                return null;
            }

            var end = self.cur;
            while (end[0] != 0) : (end += 1) {
                if (@intFromPtr(end) >= @intFromPtr(self.end)) {
                    break;
                }
            }
            const ret = self.cur[0..(end - self.cur)];
            self.cur = end + 1;
            return ret;
        }
    };

    /// DTB tokens.
    const Token = enum(u32) {
        begin_node = 0x1,
        end_node = 0x2,
        prop = 0x3,
        nop = 0x4,
        end = 0x9,
        _,

        pub fn from(value: Chunk) Token {
            const v = @as(*const u32, @ptrCast(@alignCast(&value))).*;
            return @enumFromInt(bits.fromBigEndian(v));
        }

        pub fn eql(lhr: Token, rhr: Chunk) bool {
            return lhr == Token.from(rhr);
        }
    };
};

/// Flattened Devicetree Header.
///
/// All fields are in big-endian byte order.
const FdtHeader = extern struct {
    /// Magic value.
    magic: u32,
    /// Total size in bytes of the devicetree data structure.
    total_size: u32,
    /// Offset in bytes of the structure block from the beginning of the header.
    off_dt_struct: u32,
    /// Offset in bytes of the strings block from the beginning of the header.
    off_dt_strings: u32,
    /// Offset in bytes of the memory reservation map from the beginning of the header.
    off_mem_rsvmap: u32,
    /// Version of the devicetree data structure.
    version: u32,
    /// Lowest version of the devicetree data structure with which the version used is backwards compatible.
    last_comp_version: u32,
    /// Physical ID of the system's boot CPU.
    boot_cpuid_phys: u32,
    /// Length in bytes of the strings block section.
    size_dt_strings: u32,
    /// Length in bytes of the structure block section.
    size_dt_struct: u32,

    /// Get the address of the strings block.
    pub fn stringAddr(self: *const FdtHeader) usize {
        return @intFromPtr(self) + bits.fromBigEndian(self.off_dt_strings);
    }

    /// Get the size of the strings block.
    pub fn stringSize(self: *const FdtHeader) usize {
        return bits.fromBigEndian(self.size_dt_strings);
    }

    /// Get the address of the structure block.
    pub fn structAddr(self: *const FdtHeader) usize {
        return @intFromPtr(self) + bits.fromBigEndian(self.off_dt_struct);
    }

    /// Get the size of the structure block.
    pub fn structSize(self: *const FdtHeader) usize {
        return bits.fromBigEndian(self.size_dt_struct);
    }

    /// Get the null-terminated name pointed by the given offset in the strings block.
    ///
    /// The returned string does not include the null terminator.
    pub fn getName(self: *const FdtHeader, offset: u32) []const u8 {
        const strs_ptr: [*]const u8 = @ptrFromInt(self.stringAddr());
        const strs: []const u8 = strs_ptr[0..self.stringSize()];

        var end: usize = offset;
        while (strs[end] != 0) : (end += 1) {}
        return strs[offset..end];
    }
};

/// DTB node.
pub const Node = struct {
    /// Address of the beginning of the node in the structure block.
    addr: usize,
    /// The number of cells to represent the address in the `reg` property.
    addr_cells: u32,
    /// The number of cells to represent the size in the `reg` property.
    size_cells: u32,
};

/// Property value of a DTB node.
const Property = struct {
    /// Address of the property value in the structure block.
    addr: usize,
    /// The number of address cells.
    addr_cells: u32,
    /// The number of size cells.
    size_cells: u32,
    /// The length of the property value in bytes.
    len: u32,

    /// Get the raw value as a byte slice.
    pub fn slice(self: Property) []const u32 {
        return @as([*]const u32, @ptrFromInt(self.addr))[0 .. self.len / @sizeOf(u32)];
    }
};

// =============================================================
// Tests
// =============================================================

const testing = std.testing;

fn testCreateBin(bin: []const u8, strings: []const u8) ![]const u8 {
    const bin_start: u32 = @sizeOf(FdtHeader);
    const strings_start: u32 = @intCast(bin_start + bin.len);
    const total_size: u32 = strings_start + @as(u32, @intCast(strings.len));
    const header = FdtHeader{
        .magic = bits.toBigEndian(@as(u32, 0xD00DFEED)),
        .total_size = 0,
        .off_dt_struct = bits.toBigEndian(bin_start),
        .off_dt_strings = bits.toBigEndian(strings_start),
        .off_mem_rsvmap = 0,
        .version = bits.toBigEndian(@as(u32, 17)),
        .last_comp_version = bits.toBigEndian(@as(u32, 16)),
        .boot_cpuid_phys = 0,
        .size_dt_strings = bits.toBigEndian(@as(u32, @intCast(strings.len))),
        .size_dt_struct = bits.toBigEndian(@as(u32, @intCast(bin.len))),
    };

    const out = try testing.allocator.alloc(u8, total_size);
    @memcpy(out[0..@sizeOf(FdtHeader)], std.mem.asBytes(&header));
    @memcpy(out[bin_start..strings_start], bin);
    @memcpy(out[strings_start..], strings);

    return out;
}

test "Parser.nop" {
    const data = [_]u8{
        0x00, 0x00, 0x00, 0x04, // nop
        0x00, 0x00, 0x00, 0x04, // nop
        0x00, 0x00, 0x00, 0x01, // begin_node
    };
    const strings = [_]u8{};
    const bin = try testCreateBin(data[0..], strings[0..]);
    defer testing.allocator.free(bin);

    const dtb = try Dtb.new(@intFromPtr(bin.ptr));
    var parser = try Parser.new(dtb.header, null, false);

    try parser.consumeNop();
    try testing.expectEqual([_]u8{ 0x00, 0x00, 0x00, 0x01 }, try parser.peekChunk());
}

test "Parser.reg" {
    const data = [_]u8{
        0x00, 0x00, 0x00, 0x01, // begin_node
        'r', 'o', 'o', 't', // name
        0x00, 0x00, 0x00, 0x00, // padding
        0x00, 0x00, 0x00, 0x03, // prop ("compatible")
        0x00, 0x00, 0x00, 0x0C, // len
        0x00, 0x00, 0x00, 0x00, // nameoff (0)
        // "compatible" property value
        'h',  'o',  'g',  'e',
        0x00, 'f',  'u',  'g',
        'a',  'g',  'a',  0x00,
        0x00, 0x00, 0x00, 0x03, // prop ("reg")
        0x00, 0x00, 0x00, 0x18, // len (24)
        0x00, 0x00, 0x00, 0x0B, // nameoff (11)
        // "reg" property value
        0x56, 0x78, 0xAB, 0x90, // addr
        0x12, 0x34, 0x00, 0x00, // addr
        0x00, 0x00, 0xDE, 0x00, // size (0xDE00)
        0xAB, 0xCD, 0xEF, 0x00, // addr
        0x34, 0x00, 0x00, 0x00, // addr
        0x00, 0x00, 0x00, 0x90, // size (0x90)
        0x00, 0x00, 0x00, 0x02, // end_node
    };
    const strings = [_]u8{
        'c', 'o', 'm',  'p',
        'a', 't', 'i',  'b',
        'l', 'e', 0x00, 'r',
        'e', 'g', 0x00, 0x00,
    };
    const bin = try testCreateBin(data[0..], strings[0..]);
    defer testing.allocator.free(bin);
    const dtb = try Dtb.new(@intFromPtr(bin.ptr));

    // Find "fugaga" node.
    const node = try dtb.searchNode(
        .{ .compat = "fugaga" },
        null,
    );
    try testing.expectEqual(Node{
        .addr = @intFromPtr(bin.ptr) + @sizeOf(FdtHeader) + 12,
        .addr_cells = 2,
        .size_cells = 1,
    }, node);

    // Read "reg" property.
    try testing.expectEqual(hugin.mem.PhysRegion{
        .addr = 0x5678AB9012340000,
        .size = 0xDE00,
    }, try dtb.readRegProp(node.?, 0));
    try testing.expectEqual(hugin.mem.PhysRegion{
        .addr = 0xABCDEF0034000000,
        .size = 0x90,
    }, try dtb.readRegProp(node.?, 1));
    try testing.expectEqual(
        null,
        try dtb.readRegProp(node.?, 2),
    );
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");

const hugin = @import("hugin");
const bits = hugin.bits;
