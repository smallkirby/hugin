pub const Error = paging.PagingError;

pub const am = @import("asm.zig"); // TODO: should not be exported.
pub const gicv3 = @import("gicv3.zig"); // TODO: should not be exported.
pub const psci = @import("psci.zig"); // TODO:: should not be exported.
pub const regs = @import("registers.zig"); // TODO: should not be exported.

/// Register context.
pub const Context = regs.Context;

/// Fetch the BSP's page table address and set it to the current PE's TTBR0_EL2.
pub fn dupPaging() void {
    paging.dupePaging();
}

/// Get the current PE's affinity value.
pub fn getAffinity() u32 {
    return am.mrs(.mpidr_el1).packedAffinity();
}

/// Save BSP's context for later duplication to APs.
pub fn saveBspContext() void {
    paging.init();
}

/// Initialize paging.
pub fn initPaging(ipa: usize, pa: usize, size: usize, pallocator: PageAllocator) Error!void {
    try paging.initS2Table(pallocator);
    try paging.mapS2(ipa, pa, size, pallocator);
}

/// Initialize interrupts globally for EL2.
pub fn initInterruptsGlobal(dist_base: PhysRegion) gicv3.Distributor {
    // Initialize GIC distributor.
    const dist = gicv3.Distributor.new(dist_base);
    dist.init();

    return dist;
}

/// Initialize interrupts locally for EL2.
///
/// This function must be called on each PE.
pub fn initInterruptsLocal(redist_base: PhysRegion) gicv3.Redistributor {
    // Set handlers.
    isr.init();

    // Initialize GIC redistributor.
    const redist = gicv3.Redistributor.new(redist_base);
    redist.init();

    return redist;
}

/// Disable all interrupts.
pub fn disableAllInterrupts() u64 {
    const daif = am.mrs(.daif);
    am.msr(.daif, .{
        .d = daif.d,
        .a = daif.a,
        .i = true,
        .f = true,
    });
    asm volatile ("isb");

    return @bitCast(daif);
}

/// Set DAIF register.
pub fn setInterrupts(daif: u64) void {
    am.msr(.daif, @bitCast(daif));
}

/// Configure GIC distributor to enable an interrupt.
pub fn enableDistIntr(id: hugin.intr.IntrId, dist: gicv3.Distributor) void {
    dist.setGroup(id, .ns_grp1);
    dist.setPriority(id, 0);
    dist.setRouting(id, @bitCast(am.mrs(.mpidr_el1)));
    dist.setTrigger(id, .level);
    dist.clearPending(id);
    dist.enable(id);
}

/// Configure GIC redistributor to enable an interrupt.
pub fn enableRedistIntr(id: hugin.intr.IntrId, redist: gicv3.Redistributor) void {
    redist.setGroup(id, .ns_grp1);
    redist.setPriority(id, 0);
    redist.setTrigger(id, .level);
    redist.enable(id);
}

/// Halt until interrupt.
pub fn halt() void {
    asm volatile ("wfi");
}

/// Get the current exception level.
pub fn getCurrentEl() u2 {
    return am.mrs(.currentel).el;
}

/// Get the current SP.
pub inline fn getSp() usize {
    return asm volatile (
        \\mov %[sp], sp
        : [sp] "=r" (-> usize),
    );
}

/// Invalidate data cache line by virtual address.
pub fn invalidateCache(addr: anytype) void {
    const a: usize = switch (@typeInfo(@TypeOf(addr))) {
        .pointer => @intFromPtr(addr),
        .int, .comptime_int => addr,
        else => @compileError("Invalid argument."),
    };

    asm volatile (
        \\dc ivac, %[addr]
        :
        : [addr] "r" (a),
    );
}

// =============================================================
// Imports
// =============================================================

const hugin = @import("hugin");
const PageAllocator = hugin.mem.PageAllocator;
const PhysRegion = hugin.mem.PhysRegion;

const isr = @import("isr.zig");
const paging = @import("paging.zig");
