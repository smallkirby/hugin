pub const Error = paging.PagingError;

pub const am = @import("asm.zig"); // TODO: should not be exported.
pub const gicv3 = @import("gicv3.zig"); // TODO: should not be exported.
pub const regs = @import("registers.zig"); // TODO: should not be exported.

/// Register context.
pub const Context = regs.Context;

/// Initialize paging.
pub fn initPaging(ipa: usize, pa: usize, size: usize, pallocator: PageAllocator) Error!void {
    try paging.initS2Table(pallocator);
    try paging.mapS2(ipa, pa, size, pallocator);
}

/// Initialize interrupts for EL2.
pub fn initInterrupts(dist_base: PhysRegion, redist_base: PhysRegion) struct { gicv3.Distributor, gicv3.Redistributor } {
    // Set handlers.
    isr.init();

    // Initialize GIC distributor and redistributor.
    const dist = gicv3.Distributor.new(dist_base);
    dist.init();
    const redist = gicv3.Redistributor.new(redist_base);
    redist.init();

    return .{ dist, redist };
}

/// Configure GIC to enable an interrupt.
pub fn enableIntr(id: hugin.intr.IntrId, dist: gicv3.Distributor) void {
    dist.setGroup(id, .ns_grp1);
    dist.setPriority(id, 0);
    dist.setRouting(id, @bitCast(am.mrs(.mpidr_el1)));
    dist.setTrigger(id, .level);
    dist.clearPending(id);
    dist.enable(id);
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

// =============================================================
// Imports
// =============================================================

const hugin = @import("hugin");
const PageAllocator = hugin.mem.PageAllocator;
const PhysRegion = hugin.mem.PhysRegion;

const isr = @import("isr.zig");
const paging = @import("paging.zig");
