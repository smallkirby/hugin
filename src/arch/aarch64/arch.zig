pub const Error = paging.PagingError;

pub const am = @import("asm.zig"); // TODO: should not be exported.
pub const regs = @import("registers.zig"); // TODO: should not be exported.

/// Initialize paging.
pub fn initPaging(ipa: usize, pa: usize, size: usize, pallocator: PageAllocator) Error!void {
    try paging.initS2Table(pallocator);
    try paging.mapS2(ipa, pa, size, pallocator);
}

/// Initialize interrupts for EL2.
pub fn initInterrupts(dist_base: PhysRegion, redist_base: PhysRegion) void {
    // Set handlers.
    isr.init();

    // Initialize GIC distributor and redistributor.
    const dist = gicv3.Distributor.new(dist_base);
    dist.init();
    const redist = gicv3.Redistributor.new(redist_base);
    redist.init();
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

const gicv3 = @import("gicv3.zig");
const isr = @import("isr.zig");
const paging = @import("paging.zig");
