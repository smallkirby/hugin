//! Device-side implementation of Virtio Block Device over MMIO.

const Error = mmio.MmioError;

/// Virtio block device over MMIO device.
pub const VioblkDevice = struct {
    const Self = @This();
    const Register = mmio.Register;

    /// MMIO device interface.
    interface: hugin.vm.MmioDevice,

    /// Target file system info.
    ///
    /// The filesystem image is in the FAT32 filesystem.
    fs: hugin.Fat32.FileInfo,

    /// Device status.
    status: u32,
    /// Number of entries in the virtqueue.
    queue_size: u32,
    /// Virtqueue is ready.
    queue_ready: bool,
    /// Guest page size.
    page_size: usize,
    /// Descriptor table provided by the driver.
    desc: [*]virtio.QueueDesc,
    /// Available Ring provided by the driver.
    qavail: *virtio.QueueAvail,
    /// Used Ring provided by the driver.
    qused: *virtio.QueueUsed,

    /// MMIO read and write handler.
    const handler = hugin.vm.MmioDevice.Handler{
        .read = &read,
        .write = &write,
    };

    /// MMIO Device Legacy Register Layout.
    const Map = virtio.Register.Map;
    /// Status field.
    const Status = virtio.Register.Status;

    /// Maximum size of a virtqueue supported.
    const max_size_queue = 1024;

    /// Create a new Virtio Block Device driver instance.
    pub fn new(allocator: Allocator, base: usize, len: usize, fs: hugin.Fat32.FileInfo) Error!*Self {
        if (fs.size & Vblk.block_mask != 0) {
            return Error.InvalidArgument;
        }

        const self = try allocator.create(Self);
        self.* = Self{
            .interface = initInterface(self, base, len),
            .fs = fs,
            .status = 0,
            .queue_size = 0,
            .queue_ready = false,
            .page_size = virtio.page_size,
            .desc = undefined,
            .qavail = undefined,
            .qused = undefined,
        };

        return self;
    }

    fn initInterface(self: *Self, base: usize, len: usize) hugin.vm.MmioDevice {
        return .{
            .ctx = @ptrCast(self),
            .base = base,
            .len = len,
            .handler = handler,
        };
    }

    /// MMIO read handler.
    pub fn read(ctx: *anyopaque, offset: usize, width: mmio.Width) Error!Register {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const vioreg: Map = @enumFromInt(offset);

        return switch (vioreg) {
            .magic => Register{ .word = virtio.legacy_magic },
            .version => Register{ .word = virtio.legacy_version },
            .id => Register{ .word = Vblk.id_virtio_blk },
            .vendor => Register{ .word = 0xDEADBEEF },
            .feats => Register{ .word = 0 },
            .queue_size_max => Register{ .word = max_size_queue },
            .queue_pfn => if (self.queue_ready) unreachable else Register{ .word = 0 },
            .queue_ready => Register{ .word = @intFromBool(self.queue_ready) },
            .status => Register{ .word = self.status },

            else => if (@intFromEnum(Map.config) <= offset) {
                const config_offset = offset - @intFromEnum(Map.config);
                return self.readConfig(config_offset, width);
            } else {
                log.err("Unhandled virtio-blk read at offset 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        };
    }

    /// Read configuration space.
    fn readConfig(self: *Self, offset: usize, width: mmio.Width) Error!Register {
        return switch (offset) {
            // Capacity.
            0...8 => {
                const capacity: u64 = self.fs.size / Vblk.block_size;
                const value = capacity >> @as(u6, @intCast(offset * 8));
                return switch (width) {
                    .byte => Register{ .byte = @truncate(value) },
                    .hword => Register{ .hword = @truncate(value) },
                    .word => Register{ .word = @truncate(value) },
                    .dword => Register{ .dword = value },
                };
            },
            // We don't support any other config fields.
            else => unreachable,
        };
    }

    /// MMIO write handler.
    pub fn write(ctx: *anyopaque, offset: usize, value: Register) Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const vioreg: Map = @enumFromInt(offset);

        switch (vioreg) {
            .feats_sel => {},
            .gfeats => {},
            .gfeats_sel => {},
            .gpage_size => self.page_size = value.word,
            .queue_sel => {},
            .queue_size => self.queue_size = value.word,
            .queue_align => {},
            .queue_pfn => {
                const pfn: usize = value.word;
                const ipa = pfn * self.page_size;
                const phys = hugin.vm.current().ipa2pa(ipa);

                self.desc = @ptrFromInt(phys);
                self.qavail = @ptrFromInt(phys + virtio.desc_table_size);
                self.qused = @ptrFromInt(hugin.bits.roundup(
                    phys + virtio.desc_table_size + virtio.avail_ring_size,
                    self.page_size,
                ));
                log.debug("Queue provided @ 0x{X}", .{phys});
            },
            .queue_notify => if (value.word == 0) unreachable,
            .status => if (value.word == Status.reset) {
                self.reset();
            } else {
                self.status = value.word;
            },

            else => {
                log.err("Unhandled virtio-blk write at offset 0x{X}", .{offset});
                return Error.Unimplemented;
            },
        }
    }

    /// Reset the device state.
    fn reset(self: *Self) void {
        log.debug("Resetting virtio-blk device.", .{});

        self.* = Self{
            .interface = self.interface,
            .fs = self.fs,

            .status = 0,
            .queue_size = 0,
            .queue_ready = false,
            .page_size = virtio.page_size,
            .desc = undefined,
            .qavail = undefined,
            .qused = undefined,
        };
    }
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.vvblk);
const hugin = @import("hugin");
const bits = hugin.bits;
const mmio = hugin.mmio;
const virtio = hugin.drivers.virtio;

const Allocator = std.mem.Allocator;
const Vblk = hugin.drivers.VirtioBlk;
