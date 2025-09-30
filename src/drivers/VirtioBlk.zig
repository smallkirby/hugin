//! Virtio Block Device Version 1.3.

const Self = @This();
const VirtioBlk = Self;

pub const Error = VirtioBlkError;
pub const VirtioBlkError = error{
    /// Invalid virtio device.
    InvalidDevice,
    /// Address to operate on is invalid.
    InvalidAddress,
    /// Descriptor or queue is full.
    OutOfResource,
    /// I/O error.
    Io,
    /// Operation not supported by the device.
    Unsupported,
} || PageAllocator.Error;

/// Device ID of Virtio Block Device.
const id_virtio_blk: u32 = 0x2;

/// Block size in bytes.
const block_size = 512;
/// Block size mask.
const block_mask = block_size - 1;

/// Status success.
const status_ok = 0;
/// Status for device or driver error.
const status_ioerr = 1;
/// Status for a request unsupported by the device.
const status_unsupp = 2;

/// Base address of MMIO Virtio Block Device.
vreg: virtio.Register,
/// Descriptor Table.
desc_table: *[virtio.num_descs]virtio.QueueDesc,
/// Available Ring.
qavail: *virtio.QueueAvail,
/// Used Ring.
qused: *virtio.QueueUsed,
/// Bitmap to manage available descriptors.
bitmap: hugin.bitmap.Bitmap(virtio.num_descs),

/// Create a new Virtio Block Device driver instance.
pub fn new(base: usize, allocator: Allocator, pallocator: PageAllocator) Error!Self {
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
        .vreg = vreg,
        .desc_table = desc_table,
        .qavail = qavail,
        .qused = qused,
        .bitmap = try .init(allocator),
    };
}

const Operation = enum {
    read,
    write,
};

/// Send a read or write request to the device.
///
/// - `buffer`: The buffer to read to or write from.
/// - `addr`: The block address to read from or write to.
/// - `op`: The operation to perform (read or write).
pub fn operate(self: *Self, buffer: []u8, addr: u64, op: Operation) Error!void {
    if (addr & block_mask != 0) {
        return Error.InvalidAddress;
    }

    // Setup status.
    var status: u8 = 0xFF;
    const status_idx = blk: {
        const desc_idx = self.bitmap.alloc() catch return Error.OutOfResource;
        errdefer self.bitmap.free(desc_idx) catch {};
        const desc = &self.desc_table[desc_idx];
        desc.* = .{
            .addr = @intFromPtr(&status),
            .len = @sizeOf(@TypeOf(status)),
            .flags = .{ .write = true },
        };

        break :blk desc_idx;
    };

    // Setup buffer.
    const buf_idx = blk: {
        const desc_idx = self.bitmap.alloc() catch return Error.OutOfResource;
        errdefer self.bitmap.free(desc_idx) catch {};
        const desc = &self.desc_table[desc_idx];
        desc.* = .{
            .addr = @intFromPtr(buffer.ptr),
            .len = @intCast(buffer.len),
            .flags = .{ .next = true, .write = (op == .read) },
            .next = @intCast(status_idx),
        };

        break :blk desc_idx;
    };

    // Setup request.
    const req = Request{
        .type = if (op == .read) .in else .out,
        .sector = addr / block_size,
    };
    const req_idx = blk: {
        const desc_idx = self.bitmap.alloc() catch return Error.OutOfResource;
        errdefer self.bitmap.free(desc_idx) catch {};
        const desc = &self.desc_table[desc_idx];
        desc.* = .{
            .addr = @intFromPtr(&req),
            .len = @sizeOf(Request),
            .flags = .{ .next = true },
            .next = @intCast(buf_idx),
        };

        break :blk desc_idx;
    };

    // Setup Available Ring.
    self.qavail.push(@intCast(req_idx));

    // Notify the device.
    self.vreg.write(.queue_notify, 0);

    defer self.bitmap.free(req_idx) catch {};
    defer self.bitmap.free(buf_idx) catch {};
    defer self.bitmap.free(status_idx) catch {};

    // Wait for completion.
    while (true) {
        std.atomic.spinLoopHint();

        hugin.arch.invalidateCache(&status);

        const s = @as(*volatile u8, @ptrCast(&status)).*;
        if (s != 0xFF) {
            switch (s) {
                status_ok => return,
                status_ioerr => return Error.Io,
                status_unsupp => return Error.Unsupported,
                else => return Error.Io,
            }
        }
    }
}

/// Virtio Block Request.
///
/// This is a device-readonly part of the request, followed by device-write-only data and status.
const Request = extern struct {
    /// Request type.
    type: Type,
    /// Reserved.
    _reserved: u32 = 0,
    /// Offset (multiplied by 512) where the operation to occur.
    sector: u64,
    // After here, data and status follow.

    /// Request types.
    const Type = enum(u32) {
        in = 0,
        out = 1,
        flush = 4,
        get_id = 8,
        get_lifetime = 10,
        discard = 11,
        write_zeroes = 13,
        secure_erase = 14,
    };
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
const Allocator = std.mem.Allocator;
const PageAllocator = hugin.mem.PageAllocator;

const virtio = @import("virtio.zig");
