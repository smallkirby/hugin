//! VSMAv8-64 translation system.

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
        .ps = @as(u3, @intCast(@intFromEnum(parange))), // Use PA size as Stage IPA size.
        .tg0 = .size_4kib, // 4K
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
    std.log.debug("VTTBR_EL2: 0x{X:0>16}", .{@as(u64, @bitCast(vttbr))});
}

/// Get the number of required concatenated translation tables.
///
/// - `t0sz`: T0SZ value (0-48).
/// - `level`: Initial lookup level (0-3).
fn numConcatenatedTables(t0sz: u8, level: LookupLevel) usize {
    const index_width = 9; // Number of entries per table.
    const max_level = 3;
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

/// Size in bits of IA (Input Address).
const ia_size = 48;
/// Size in bits of OA (Output Address).
const oa_size = 48;

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
};

/// Page or Block descriptor for Stage 2 translation.
const PageDescriptor = packed struct(u64) {
    /// Valid descriptor.
    valid: bool = true,
    /// Page descriptor
    page: bool,
    /// Lower attributes.
    lattr: LowerAttr,
    /// Reserved when FEAT_XS is not implemented.
    _reserved0: u1 = 0,
    /// Output address.
    oa: u36,
    /// Reserved when OA is 48 bits.
    _reserved1: u2 = 0,
    /// Reserved.
    _reserved2: u1 = 0,
    /// Upper attributes.
    uattr: UpperAttr,
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
const am = @import("asm.zig");
const regs = @import("registers.zig");

const PageAllocator = hugin.mem.PageAllocator;
