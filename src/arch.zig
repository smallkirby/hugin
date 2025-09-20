// Export arch-specific implementation.
pub const impl = switch (builtin.target.cpu.arch) {
    .aarch64 => @import("arch/aarch64/arch.zig"),
    else => @compileError("Unsupported architecture."),
};

const builtin = @import("builtin");
