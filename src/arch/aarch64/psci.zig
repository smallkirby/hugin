//! ARM Power State Coordination Interface (PSCI) implementation.

pub const Error = error{
    /// Function not supported.
    NotSupported,
    /// PSCI returned INVALID_PARAMETERS.
    InvalidParam,
    /// PSCI returned DENIED.
    Denied,
    /// PSCI returned ALREADY_ON.
    AlreadyOn,
    /// PSCI returned ON_PENDING.
    OnPending,
    /// PSCI returned INTERNAL_FAILURE.
    InternalFailure,
    /// PSCI returned NOT_PRESENT.
    NotPresent,
    /// PSCI returned DISABLED.
    Disabled,
    /// PSCI returned INVALID_ADDRESS.
    InvalidAddress,
};

/// PSCI error codes.
const ErrorCodes = enum(i64) {
    success = 0,
    not_supported = -1,
    invalid_param = -2,
    denied = -3,
    already_on = -4,
    on_pending = -5,
    internal_failure = -6,
    not_present = -7,
    disabled = -8,
    invalid_address = -9,

    /// Convert PSCI error code to `Error`.
    pub fn unwrap(self: ErrorCodes) Error {
        return switch (self) {
            .success => unreachable,
            .not_supported => Error.NotSupported,
            .invalid_param => Error.InvalidParam,
            .denied => Error.Denied,
            .already_on => Error.AlreadyOn,
            .on_pending => Error.OnPending,
            .internal_failure => Error.InternalFailure,
            .not_present => Error.NotPresent,
            .disabled => Error.Disabled,
            .invalid_address => Error.InvalidAddress,
        };
    }
};

/// SMC64 function IDs.
const Func = union(enum(u64)) {
    /// Return the version of PSCI implemented.
    psci_version: struct {
        /// Not used.
        x1: u64 = 0,
        /// Not used.
        x2: u64 = 0,
        /// Not used.
        x3: u64 = 0,
    } = 0x8400_0000,

    /// Power up a core.
    cpu_on: struct {
        /// Target CPU ID.
        ///
        /// Contains a copy of the affinity fields of the MPIDR register.
        x1: u64,
        /// Entry point address.
        x2: u64,
        /// Argument to pass to the entry point.
        x3: u64,
    } = 0xC400_0003,
};

/// PSCI version.
const Version = packed struct(u32) {
    /// Minor version.
    minor: u16,
    /// Major version.
    major: u16,
};

/// Get the PSCI version.
pub fn getVersion() Error!Version {
    const ret = try psci(.{ .psci_version = .{} });
    return @bitCast(@as(u32, @truncate(ret)));
}

/// Wake up a core.
pub fn awakePe(target: u64, entry: u64, arg: u64) Error!void {
    _ = try psci(.{ .cpu_on = .{
        .x1 = target,
        .x2 = entry,
        .x3 = arg,
    } });
}

/// Call a PSCI function.
fn psci(func: Func) Error!u64 {
    const ret = switch (func) {
        inline else => |v| am.smc(@intFromEnum(func), v.x1, v.x2, v.x3),
    };
    const iret: i64 = @bitCast(ret);

    if (iret < 0) {
        return @as(ErrorCodes, @enumFromInt(iret)).unwrap();
    } else {
        return ret;
    }
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const am = @import("asm.zig");
