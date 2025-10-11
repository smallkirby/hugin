pub const IntrError = error{
    /// The interrupt is already registered.
    AlreadyRegistered,
    /// The interrupt system is not initialized.
    NotInitialized,
    /// Target not found.
    NotFound,
} || hugin.dtb.DtbError;

/// Interrupt ID.
pub const IntrId = u10;
/// Interrupt Priority.
pub const Priority = u8;

/// GIC distributor.
var dist: hugin.arch.gicv3.Distributor = undefined;

/// Base interrupt ID of SGI.
pub const sgi_base = 0;
/// Base interrupt ID of PPI.
pub const ppi_base = 16;
/// Base interrupt ID of SPI.
pub const spi_base = 32;

/// Maximum number of interrupt handlers
pub const max_num_handlers = 256;

/// Interrupt handlers.
var handlers: [max_num_handlers]Handler = [_]Handler{unhandledHandler} ** max_num_handlers;

/// List of initialized GIC redistributors.
var redists = std.AutoHashMap(u32, hugin.arch.gicv3.Redistributor).init(allocator);

/// Interrupt handler function signature.
///
/// If the handler returns `true`, the interrupt is deactivated.
pub const Handler = *const fn (*arch.regs.Context) bool;

/// Interrupt kind.
pub const Kind = enum {
    /// Software Generated Interrupt.
    sgi,
    /// Private Peripheral Interrupt.
    ppi,
    /// Shared Peripheral Interrupt.
    spi,

    pub fn base(self: Kind) IntrId {
        return switch (self) {
            .sgi => sgi_base,
            .ppi => ppi_base,
            .spi => spi_base,
        };
    }
};

/// Initialize interrupts.
pub fn initGlobal(dtb: hugin.dtb.Dtb) IntrError!void {
    const gic_node = try dtb.searchNode(
        .{ .compat = "arm,gic-v3" },
        null,
    ) orelse {
        return IntrError.NotFound;
    };
    const dist_reg = try dtb.readRegProp(gic_node, 0) orelse {
        return IntrError.NotFound;
    };

    dist = arch.initInterruptsGlobal(dist_reg);
}

/// Initialize interrupts locally.
///
/// This function must be called on each PE.
pub fn initLocal(dtb: hugin.dtb.Dtb) IntrError!void {
    const gic_node = try dtb.searchNode(
        .{ .compat = "arm,gic-v3" },
        null,
    ) orelse {
        return IntrError.NotFound;
    };
    const redist_reg = try dtb.readRegProp(gic_node, 1) orelse {
        return IntrError.NotFound;
    };

    // Initialize GIC locally.
    const redist = arch.initInterruptsLocal(redist_reg);

    // Register the redistributor.
    const affi = arch.getAffinity();
    redists.put(affi, redist) catch return IntrError.NotInitialized;
}

/// Dispatches the interrupt to the appropriate handler.
///
/// Called from the ISR stub.
///
/// If the handler returns `true`, the interrupt should be deactivated.
/// Otherwise, the priority should be just dropped.
pub fn dispatch(vector: u24, context: *arch.regs.Context) bool {
    return handlers[vector](context);
}

/// Enable an interrupt for the given ID and kind.
pub fn enable(offset: IntrId, kind: Kind, handler: Handler) IntrError!void {
    const vector = offset + kind.base();

    // Set handler.
    if (handlers[vector] != unhandledHandler) {
        return IntrError.AlreadyRegistered;
    }
    handlers[vector] = handler;

    // Enable interrupt in GIC.
    try enableLocal(offset, kind);
}

/// Enable an interrupt for the given ID and kind.
///
/// The handler must be already registered.
pub fn enableLocal(offset: IntrId, kind: Kind) IntrError!void {
    const vector = offset + kind.base();

    // Enable interrupt in GIC.
    const redist = redists.get(arch.getAffinity()) orelse return IntrError.NotInitialized;
    switch (kind) {
        .spi => arch.enableDistIntr(vector, dist),
        .ppi, .sgi => arch.enableRedistIntr(vector, redist),
    }
}

fn unhandledHandler(_: *arch.regs.Context) bool {
    hugin.unimplemented("Unhandled interrupt");
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const arch = hugin.arch;
const allocator = hugin.mem.general_allocator;
const PhysRegion = hugin.mem.PhysRegion;
