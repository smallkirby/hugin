//! Virtio Block Device Version 1.3.

const Self = @This();
const VirtioBlk = Self;

pub const Error = VirtioBlkError;
pub const VirtioBlkError = error{
    /// Invalid virtio device.
    InvalidDevice,
} || PageAllocator.Error;

/// Device ID of Virtio Block Device.
const id_virtio_blk: u32 = 0x2;

/// Base address of MMIO Virtio Block Device.
base: usize,
/// Descriptor Table.
desc_table: *[virtio.num_descs]virtio.QueueDesc,
/// Available Ring.
qavail: *virtio.QueueAvail,
/// Used Ring.
qused: *virtio.QueueUsed,

/// Create a new Virtio Block Device driver instance.
pub fn new(base: usize, pallocator: PageAllocator) Error!Self {
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

    // Setup VirtQueue.
    vreg.write(.gpage_size, virtio.page_size);
    vreg.write(.queue_sel, 0);

    if (virtio.num_descs > vreg.read(.queue_size_max)) {
        return Error.InvalidDevice;
    }
    vreg.write(.queue_size, virtio.num_descs);

    const queue = try pallocator.allocPages(virtio.queue_size / hugin.mem.page_size);
    errdefer pallocator.freePages(queue);
    @memset(queue, 0);
    vreg.write(.queue_pfn, @intCast(hugin.mem.virt2phys(queue) >> hugin.mem.page_shift));

    // Notify setup complete.
    vreg.write(.status, vreg.read(.status) | virtio.Register.Status.driver_ok);

    // Calculate pointers.
    const qptr = @intFromPtr(queue.ptr);
    const desc_table: *[virtio.num_descs]virtio.QueueDesc = @ptrFromInt(qptr);
    const qavail: *virtio.QueueAvail = @ptrFromInt(qptr + virtio.desc_table_size);
    const qused: *virtio.QueueUsed = @ptrFromInt(hugin.bits.roundup(
        qptr + virtio.desc_table_size + virtio.avail_ring_size,
        virtio.page_size,
    ));

    return Self{
        .base = base,
        .desc_table = desc_table,
        .qavail = qavail,
        .qused = qused,
    };
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const PageAllocator = hugin.mem.PageAllocator;

const virtio = @import("virtio.zig");
