//! Virtio Block Device Version 1.3.

const Self = @This();
const VirtioBlk = Self;

pub const VirtioBlkError = error{
    /// Invalid virtio device.
    InvalidDevice,
};
const Error = VirtioBlkError;

/// Device ID of Virtio Block Device.
const id_virtio_blk: u32 = 0x2;

/// Create a new Virtio Block Device driver instance.
pub fn new(base: usize) Error!Self {
    const vreg = virtio.Register.from(base);

    // Check device identity.
    if (vreg.read(.magic) != virtio.legacy_magic) {
        return Error.InvalidDevice;
    }
    if (vreg.read(.version) != virtio.legacy_version) {
        return Error.InvalidDevice;
    }
    if (vreg.read(.id) != id_virtio_blk) {
        return Error.InvalidDevice;
    }

    // Reset device.
    vreg.write(.status, 0);
    // Acknowledge the device.
    vreg.write(.status, vreg.read(.status) | virtio.Register.Status.ack);

    // Get device features.
    vreg.write(.status, vreg.read(.status) | virtio.Register.Status.driver);
    const feats = vreg.read(.feats);
    const feat_ro = 1 << 5;
    if (feats & feat_ro != 0) {
        return Error.InvalidDevice;
    }
    // Clear driver features.
    vreg.write(.gfeats, 0);
    vreg.write(.status, vreg.read(.status) | virtio.Register.Status.features_ok);

    hugin.unimplemented("VirtioBlk.new()");
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");

const virtio = @import("virtio.zig");
