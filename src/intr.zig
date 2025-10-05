pub const IntrError = error{
    /// The interrupt is already registered.
    AlreadyRegistered,
};

/// Interrupt ID.
pub const IntrId = u10;
/// Interrupt Priority.
pub const Priority = u8;

/// GIC distributor.
var dist: hugin.arch.gicv3.Distributor = undefined;
/// GIC redistributor.
var redist: hugin.arch.gicv3.Redistributor = undefined;

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

/// Interrupt handler function signature.
pub const Handler = *const fn (*arch.regs.Context) void;

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
pub fn init(dist_range: PhysRegion, redist_range: PhysRegion) void {
    // Initialize GIC.
    dist, redist = arch.initInterrupts(dist_range, redist_range);
}

/// Dispatches the interrupt to the appropriate handler.
///
/// Called from the ISR stub.
pub fn dispatch(vector: u24, context: *arch.regs.Context) void {
    handlers[vector](context);
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
    switch (kind) {
        .spi => arch.enableDistIntr(vector, dist),
        .ppi => arch.enableRedistIntr(vector, redist),
        .sgi => hugin.unimplemented("Enable SGI"),
    }
}

fn unhandledHandler(_: *arch.regs.Context) void {
    hugin.unimplemented("Unhandled interrupt");
}

// =============================================================
// Imports
// =============================================================

const hugin = @import("hugin");
const arch = hugin.arch;
const PhysRegion = hugin.mem.PhysRegion;
