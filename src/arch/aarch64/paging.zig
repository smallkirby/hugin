//! VSMAv8-64 translation system for Stage 2 translation.

pub const PagingError = hugin.mem.MemError;

/// Initialize Stage 2 translation table.
pub fn initS2Table(allocator: PageAllocator) PagingError!void {
    const parange = am.mrs(.id_aa64mmfr0_el1).parange;
    const t0sz: u8, const initial_level: LookupLevel = switch (parange) {
        .bits_32 => .{ 32, 1 },
        .bits_36 => .{ 28, 1 },
        .bits_40 => .{ 24, 1 },
        .bits_42 => .{ 22, 1 },
        .bits_44 => .{ 20, 0 },
        .bits_48 => .{ 16, 0 },
        else => .{ 16, 0 },
    };
    const num_concat_tables = numConcatenatedTables(t0sz, initial_level);

    // Zero out root tables.
    const root_table_pages = try allocator.allocPages(num_concat_tables); // TODO: align in case # of tables > 1.
    @memset(root_table_pages, 0);

    // Set VTCR_EL2 and VTTBR_EL2.
    const sl0: u2 = if (initial_level == 1) 0b01 else 0b10;
    const vtcr_el2 = std.mem.zeroInit(regs.VtcrEl2, .{
        .ps = @as(u3, @intCast(@intFromEnum(parange))), // Use PA size as IPA size.
        .tg0 = .size_4kib,
        .sh0 = .inner,
        .orgn0 = .wbranwac,
        .irgn0 = .wbranwac,
        .sl0 = sl0,
        .t0sz = @as(u6, @intCast(t0sz)),
    });
    am.msr(.vtcr_el2, vtcr_el2);

    const vttbr = regs.VttbrEl2{
        .baddr = @truncate(@intFromPtr(root_table_pages.ptr)),
        .vmid = 0,
    };
    am.msr(.vttbr_el2, vttbr);
}

/// Map the given IPA `[pa, pa + size)` to PA `[ipa, ipa + size)`.
pub fn mapS2(ipa: usize, pa: usize, size: usize, pallocator: PageAllocator) PagingError!void {
    hugin.rtt.expectEqual(0, pa % mem.size_4kib);
    hugin.rtt.expectEqual(0, ipa % mem.size_4kib);
    hugin.rtt.expectEqual(0, size % mem.size_4kib);

    const vttbr = am.mrs(.vttbr_el2);
    const vctr = am.mrs(.vtcr_el2);

    const sl0 = vctr.sl0;
    const t0sz = vctr.t0sz;
    const initial_level: LookupLevel = switch (sl0) {
        0b00 => 2,
        0b01 => 1,
        0b10 => 0,
        0b11 => 3,
    };
    const num_descs = numConcatenatedTables(t0sz, initial_level);

    var state = TransState{
        .allocator = pallocator,
        .pa = pa,
        .ipa = ipa,
        .remain = size,
        .perm = .rw,
    };
    try mapS2Recursive(
        &state,
        initial_level,
        vttbr.baddr,
        num_descs,
    );

    asm volatile (
        \\dsb ishst
        \\tlbi alle1is
    );
}

/// Page walk to lookup the given IPA.
pub fn lookup(ipa: usize) ?usize {
    const vttbr = am.mrs(.vttbr_el2);
    const vctr = am.mrs(.vtcr_el2);
    const sl0 = vctr.sl0;
    const initial_level: LookupLevel = switch (sl0) {
        0b00 => 2,
        0b01 => 1,
        0b10 => 0,
        0b11 => 3,
    };

    return lookupRecursive(ipa, initial_level, vttbr.baddr);
}

fn lookupRecursive(ipa: usize, level: LookupLevel, tbl: usize) ?usize {
    const shift: u6 = @intCast(mem.page_shift_4kib + (max_level - level) * indexable_bits);
    const index = (ipa >> shift) & 0x1ff;
    const table = @as([*]u64, @ptrFromInt(tbl))[0..512];
    const desc = table[index];

    // Block descriptor.
    blk: {
        const bdesc: PageDescriptor = @bitCast(desc);
        if (!bdesc.valid or bdesc.page) break :blk;
        if (level == max_level) break :blk;

        const bsize = @as(usize, 1) << shift;
        return bdesc.getOa() | (ipa & (bsize - 1));
    }

    // Table descriptor.
    blk: {
        const tdesc: TableDescriptor = @bitCast(desc);
        if (!tdesc.valid or !tdesc.table) break :blk;
        if (level == max_level) break :blk;

        const nlta = tdesc.getNlta();
        return lookupRecursive(ipa, level + 1, nlta);
    }

    // Page descriptor.
    blk: {
        const pdesc: PageDescriptor = @bitCast(desc);
        if (level != max_level) break :blk;
        if (!pdesc.valid or !pdesc.page) break :blk;

        return pdesc.getOa() | (ipa & mem.page_mask_4kib);
    }

    return null;
}

/// Recursively map the given IPA to PA.
///
/// This function maps pages using Block descriptors whenever possible.
fn mapS2Recursive(state: *TransState, level: LookupLevel, tbl: usize, num_descs: usize) PagingError!void {
    const shift: u6 = @intCast(mem.page_shift_4kib + (max_level - level) * indexable_bits);
    const index = (state.ipa >> shift) & (num_descs - 1);
    const table = @as([*]u64, @ptrFromInt(tbl))[0..num_descs];

    // Map pages using Page descriptors.
    if (level == max_level) {
        for (table[index..]) |*desc| {
            var pdesc = std.mem.zeroInit(PageDescriptor, .{
                .page = true,
                .valid = true,
            });
            pdesc.lattr.s2ap = state.perm;
            pdesc.lattr.memattr = 0b1111; // Normal memory, Write-Back Read-Allocate Write-Allocate Cacheable.
            pdesc.lattr.sh = .inner;
            pdesc.lattr.af = true; // Prevent access flag fault on translations.
            pdesc.setOa(state.pa);

            desc.* = @bitCast(pdesc);

            state.ipa += mem.size_4kib;
            state.pa += mem.size_4kib;
            state.remain -= mem.size_4kib;

            if (state.remain == 0) return;
        }

        return;
    }

    for (table[index..]) |*desc| {
        const block_size = @as(usize, 1) << shift;

        // Map using Block descriptor if possible.
        if (canUseBlock(level, state.remain, state.pa, state.ipa, block_size)) {
            var bdesc = std.mem.zeroInit(PageDescriptor, .{
                .page = false,
                .valid = true,
            });
            bdesc.lattr.s2ap = state.perm;
            bdesc.lattr.memattr = 0b1111; // Normal memory, Write-Back Read-Allocate Write-Allocate Cacheable.
            bdesc.lattr.sh = .inner;
            bdesc.lattr.af = true; // Prevent access flag fault on translations.
            bdesc.setOa(state.pa);

            desc.* = @bitCast(bdesc);

            state.ipa += block_size;
            state.pa += block_size;
            state.remain -= block_size;

            if (state.remain == 0) return else continue;
        }

        // Map next level table.
        const tdesc: *TableDescriptor = @ptrCast(desc);
        if (!(tdesc.valid and tdesc.table)) {
            const next = try state.allocator.allocPages(1);
            @memset(next, 0);

            tdesc.table = true;
            tdesc.setNlta(@intFromPtr(next.ptr));
            tdesc.valid = true;
        }

        // Recursively map next level table.
        const nlta = tdesc.getNlta();
        try mapS2Recursive(state, level + 1, nlta, 512);

        if (state.remain == 0) return;
    }
}

/// State for recursive table walk to map Stage 2 translation table.
const TransState = struct {
    allocator: PageAllocator,
    pa: usize,
    ipa: usize,
    remain: usize,
    perm: S2ap,
};

/// Get the number of required concatenated translation tables.
///
/// - `t0sz`: T0SZ value (0-48).
/// - `level`: Initial lookup level (0-3).
fn numConcatenatedTables(t0sz: u8, level: LookupLevel) usize {
    const index_width = 9; // Number of entries per table.
    const offset_width = 12; // Width in bits of offset within a page.
    const va_bits: u64 = 64 - t0sz; // VA size in bits.
    const levels: u64 = @intCast(max_level - level); // Number of levels to walk.
    const top_bits = va_bits - offset_width - levels * index_width;

    if (top_bits <= index_width) {
        // Single table is enough.
        return 1;
    } else {
        return std.math.pow(usize, 2, top_bits - index_width);
    }
}

/// Check if the given IPA to PA mapping can be done using a Block descriptor.
fn canUseBlock(level: LookupLevel, remain: usize, pa: usize, ipa: usize, bsize: usize) bool {
    const mask = bsize - 1;
    return (1 <= level and level < max_level) and
        (remain >= bsize) and
        (pa & mask == 0) and
        (ipa & mask == 0);
}

/// Size in bits of IA (Input Address).
const ia_size = 48;
/// Size in bits of OA (Output Address).
const oa_size = 48;
/// Number of bits that are used to index into a table.
const indexable_bits = 9;
/// Max level of translation table.
const max_level = 3;

/// Lookup level.
const LookupLevel = i8;

/// Table descriptor for Stage 2 translation.
const TableDescriptor = packed struct(u64) {
    /// Valid descriptor.
    valid: bool = true,
    /// Table descriptor.
    table: bool = true,
    /// Ignored.
    _ignored0: u6 = 0,
    /// Ignored when OA is 48 bits.
    _ignored1: u2 = 0,
    /// Ignored when Hardware managed Table descriptor Access flag is not enabled.
    _ignored2: u1 = 0,
    /// Ignored.
    _ignored3: u1 = 0,
    /// Next level table address.
    nlta: u36,
    /// Reserved when OA is 48 bits.
    _reserved0: u2 = 0,
    /// Reserved.
    _reserved1: u1 = 0,
    /// Ignored.
    _ignored4: u1 = 0,
    /// Ignored when PnCH is 0.
    _ignored5: u1 = 0,
    /// Ignored.
    _ignored6: u6 = 0,
    /// Attributes (not used by Hugin).
    attributes: u5 = 0,

    pub fn setNlta(self: *TableDescriptor, nlta: usize) void {
        self.nlta = @intCast(nlta >> mem.page_shift_4kib);
    }

    pub fn getNlta(self: *const TableDescriptor) usize {
        return @as(usize, self.nlta) << mem.page_shift_4kib;
    }
};

/// Page or Block descriptor for Stage 2 translation.
const PageDescriptor = packed struct(u64) {
    /// Valid descriptor.
    valid: bool = true,
    /// Page descriptor
    page: bool,
    /// Lower attributes.
    lattr: LowerAttr,
    /// Output address.
    oa: u36,
    /// Reserved when OA is 48 bits.
    _reserved1: u2 = 0,
    /// Reserved.
    _reserved2: u1 = 0,
    /// Upper attributes.
    uattr: UpperAttr,

    pub fn setOa(self: *PageDescriptor, oa: usize) void {
        self.oa = @intCast(oa >> mem.page_shift_4kib);
    }

    pub fn getOa(self: PageDescriptor) usize {
        return @as(usize, self.oa) << mem.page_shift_4kib;
    }
};

/// Lower attributes for Stage 2 page descriptor.
const LowerAttr = packed struct(u10) {
    /// Memory type and cacheability attribute for Stage 2.
    memattr: u4,
    /// Stage 2 access permissions when Stage 2 Indirect permissions are disabled.
    s2ap: S2ap,
    /// Shareability.
    sh: Shareability,
    /// Access flag.
    af: bool,
    /// FnXS.
    ///
    /// When false, the XS attribute of the memory is not modified.
    /// When true, the XS attribute of the memory is set to 0.
    fnxs: bool,
};

/// Upper attributes for Stage 2 page descriptor.
const UpperAttr = packed struct(u13) {
    /// Dirty bit modifier.
    dbm: bool,
    /// Contiguous bit.
    contiguous: bool,
    /// Instruction access permissions.
    xn: u2,
    /// Non-secure.
    ns: bool,
    /// Reserved for software use.
    system: u2 = 0,
    /// AssuredOnly.
    ao: bool,
    /// Page Based Hardware attributes.
    pbha: u4,
    /// Alternate MECID.
    amec: bool,
};

/// Stage 2 Shareability.
const Shareability = enum(u2) {
    /// Non-shareable.
    non = 0b00,
    /// Reserved.
    _reserved = 0b01,
    /// Outer Sharable.
    outer = 0b10,
    /// Inner Sharable.
    inner = 0b11,
};

/// Stage 2 data access permissions.
const S2ap = enum(u2) {
    /// No data access.
    non = 0b00,
    /// Read-only.
    ro = 0b01,
    /// Write-only.
    wo = 0b10,
    /// Read / Write.
    rw = 0b11,
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.paging);
const hugin = @import("hugin");
const mem = hugin.mem;
const am = @import("asm.zig");
const regs = @import("registers.zig");

const PageAllocator = mem.PageAllocator;
