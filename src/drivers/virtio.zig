//! Virtual I/O over MMIO Version 1.3.
//!
//! Only legacy interface is supported.

/// Magic value.
pub const legacy_magic: u32 = 0x74726976; // "virt"
/// Device version for legacy interface.
pub const legacy_version: u32 = 0x00000001;

/// MMIO Device Legacy Register Layout.
pub const Register = struct {
    base: usize,

    const Map = enum(usize) {
        /// Magic value.
        magic = 0x000,
        /// Device version number.
        version = 0x004,
        /// Virtio Subsystem Device ID.
        id = 0x008,
        /// Virtio Subsystem Vendor ID.
        vendor = 0x00c,
        /// Flags representing features the device supports.
        feats = 0x010,
        /// Device features word selection.
        feats_sel = 0x014,
        /// Flags representing features understood and activated by the driver.
        gfeats = 0x020,
        /// Activated (guest) features word selection.
        gfeats_sel = 0x024,
        /// Guest page size.
        gpage_size = 0x028,
        /// Virtqueue index.
        queue_sel = 0x030,
        /// Maximum virtqueue size.
        queue_size_max = 0x034,
        /// Virtqueue size.
        queue_size = 0x038,
        /// Used Ring alignment in the virtqueue.
        queue_align = 0x03c,
        /// Guest physical page number of the virtqueue.
        queue_pfn = 0x040,
        /// Queue notifier.
        queue_notify = 0x050,
        /// Interrupt status.
        interrupt_status = 0x060,
        /// Interrupt acknowledge.
        interrupt_ack = 0x064,
        /// Device status.
        status = 0x070,
    };

    /// Status field values.
    pub const Status = struct {
        pub const ack: u32 = 1;
        pub const driver: u32 = 2;
        pub const driver_ok: u32 = 4;
        pub const features_ok: u32 = 8;
    };

    pub fn from(base: usize) Register {
        return .{ .base = base };
    }

    pub fn read(self: Register, reg: Map) u32 {
        return @as(*volatile u32, @ptrFromInt(self.base + @intFromEnum(reg))).*;
    }

    pub fn write(self: Register, reg: Map, value: u32) void {
        @as(*volatile u32, @ptrFromInt(self.base + @intFromEnum(reg))).* = value;
    }
};

/// Guest page size.
pub const page_size = 4096;
/// Number of descriptors in a Virtqueue Available Ring and Used Ring.
pub const num_descs = 64;

/// Size in bytes of the Descriptor Table.
pub const desc_table_size = @sizeOf(QueueDesc) * num_descs;
/// Size in bytes of the Available Ring.
pub const avail_ring_size = @sizeOf(QueueAvail);
/// Size in bytes of the Used Ring.
pub const used_ring_size = @sizeOf(QueueUsed);
/// Memory size in bytes to allocate for a virtqueue.
///
/// Used Ring must be placed in the next page of the Available Ring.
pub const queue_size =
    hugin.bits.roundup(desc_table_size + avail_ring_size, page_size) +
    hugin.bits.roundup(used_ring_size, page_size);

/// Virtqueue Descriptor: Entry in the Descriptor Table.
///
/// It refers to the buffers the driver is using for the device.
pub const QueueDesc = extern struct {
    /// Physical address of the buffer.
    addr: u64,
    /// Buffer length.
    len: u32,
    /// Flags
    flags: Flag,
    /// Next field index if flags has NEXT bit set.
    next: u16 = 0,

    const Flag = packed struct(u16) {
        /// Buffer continues via the next field.
        next: bool = false,
        /// Buffer is device write-only, indicating driver cant't write (otherwise device read-only).
        write: bool = false,
        /// Reserved.
        _reserved: u14 = 0,
    };
};

/// Virtqueue Available Ring.
///
/// The driver uses this to offer buffers to the device.
pub const QueueAvail = extern struct {
    /// Flags.
    flags: u16,
    /// Indicates where the driver would put the next descriptor entry in the ring.
    idx: u16,
    /// Ring of descriptor indices.
    ring: [num_descs]u16,
    ///
    used_event: u16,

    pub fn push(self: *QueueAvail, idx: u16) void {
        self.ring[self.idx % num_descs] = idx;
        self.idx +%= 1;
    }
};

/// Virtqueue Used Ring.
///
/// This is where the device returns buffers once it is done with them.
pub const QueueUsed = extern struct {
    /// Flags.
    flags: u16,
    /// Indicates where the device would put the next descriptor entry in the ring.
    idx: u16,
    /// Ring of used elements.
    ring: [num_descs]Elem,
    ///
    avail_event: u16,

    const Elem = extern struct {
        /// Index of start of used descriptor chain.
        id: u32,
        /// The number of bytes written into the device writable portion of the buffer described by the descriptor chain.
        len: u32,
    };
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const hugin = @import("hugin");
