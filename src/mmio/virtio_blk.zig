//! Device-side implementation of Virtio Block Device over MMIO.

const Error = mmio.MmioError;

/// Interrupt ID for Virtio Block Device.
const intid_virtio_blk = 40;

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
    /// FAT32 block device.
    ///
    /// Used to perform actual block I/O operations.
    fat: Fat32,

    /// Device status.
    status: u32,
    /// Interrupt status.
    interrupt_status: u32,
    /// Number of entries in the virtqueue.
    queue_size: u32,
    /// Virtqueue is ready.
    queue_ready: bool,
    /// Guest page size.
    page_size: usize,
    /// Descriptor table provided by the driver.
    desc: [*]volatile virtio.QueueDesc,
    /// Available Ring provided by the driver.
    qavail: *volatile PartialQueueAvail,
    /// Used Ring provided by the driver.
    qused: *volatile PartialQueueUsed,

    /// Next index in the Available Ring to process.
    next_avail_idx: u16,

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
    pub fn new(allocator: Allocator, base: usize, len: usize, fs: hugin.Fat32.FileInfo, fat: Fat32) Error!*Self {
        if (fs.size & Vblk.block_mask != 0) {
            return Error.InvalidArgument;
        }

        const self = try allocator.create(Self);
        self.* = Self{
            .interface = initInterface(self, base, len),
            .fs = fs,
            .fat = fat,

            .status = 0,
            .interrupt_status = 0,
            .queue_size = 0,
            .queue_ready = false,
            .page_size = virtio.page_size,
            .desc = undefined,
            .qavail = undefined,
            .qused = undefined,

            .next_avail_idx = 0,
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
            .interrupt_status => Register{ .word = self.interrupt_status },
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
                const phys = hugin.vm.local().ipa2pa(ipa);

                const desc_table_size = self.queue_size * @sizeOf(virtio.QueueDesc);
                self.desc = @ptrFromInt(phys);
                self.qavail = @ptrFromInt(phys + desc_table_size);
                self.qused = @ptrFromInt(hugin.bits.roundup(
                    phys + desc_table_size + @sizeOf(PartialQueueAvail) + @sizeOf(u16) * self.queue_size,
                    self.page_size,
                ));
                log.debug("Queue provided @ 0x{X}", .{phys});
            },
            .queue_notify => if (value.word == 0) self.operate(),
            .interrupt_ack => self.interrupt_status &= ~value.word,
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
            .fat = self.fat,

            .status = 0,
            .interrupt_status = 0,
            .queue_size = 0,
            .queue_ready = false,
            .page_size = virtio.page_size,
            .desc = undefined,
            .qavail = undefined,
            .qused = undefined,

            .next_avail_idx = 0,
        };
    }

    /// Handle available requests.
    ///
    /// This function only supports simple read and write requests.
    fn operate(self: *Self) void {
        while (self.getNextAvail()) |idx| {
            const descid = self.qavail.ring(idx);
            var desc = &self.desc[descid];

            if (desc.len != @sizeOf(Vblk.Request)) {
                log.err("Invalid request descriptor length: {}", .{desc.len});
                return;
            }
            if (!desc.flags.next) {
                log.err("Expected chained descriptor, got single descriptor.", .{});
                return;
            }

            const reqaddr = hugin.vm.local().ipa2pa(desc.addr);
            const req: *Vblk.Request = @ptrFromInt(reqaddr);
            if (req.type != .in and req.type != .out) {
                log.err("Unsupported request type: {t}", .{req.type});
                return;
            }

            var offset = req.sector * Vblk.block_size;
            var ret: u8 = Vblk.status_ok;
            var total: u32 = 0;

            // Process until the status descriptor.
            desc = &self.desc[desc.next];
            const status_desc = while (desc.flags.next) : (desc = &self.desc[desc.next]) {
                total += desc.len;

                const buf: [*]u8 = @ptrFromInt(hugin.vm.local().ipa2pa(desc.addr));
                if (req.type == .out) {
                    offset += self.fat.write(self.fs, buf[0..desc.len], offset, palloc) catch err: {
                        log.err("Failed to write to FAT32 filesystem.", .{});
                        ret = Vblk.status_ioerr;
                        break :err 0;
                    };
                } else {
                    offset += self.fat.read(self.fs, buf[0..desc.len], offset, palloc) catch err: {
                        log.err("Failed to read from FAT32 filesystem.", .{});
                        ret = Vblk.status_ioerr;
                        break :err 0;
                    };
                }
            } else desc;

            // Write status.
            const status_buf: *volatile u8 = @ptrFromInt(hugin.vm.local().ipa2pa(status_desc.addr));
            status_buf.* = ret;
            total += status_desc.len;

            // Update Used Ring.
            self.qused.push(descid, total, self.queue_size);
        }

        // Inject an interrupt.
        self.interrupt_status = 1;
        hugin.vm.local().injectInterrupt(intid_virtio_blk, null);
    }

    /// Get the next available index in the Available Ring.
    fn getNextAvail(self: *Self) ?u32 {
        if (self.next_avail_idx == self.qavail.idx) {
            return null;
        }

        const next = self.next_avail_idx % self.queue_size;
        self.next_avail_idx += 1;
        return next;
    }
};

/// Virtqueue Available Ring.
///
/// The driver uses this to offer buffers to the device.
const PartialQueueAvail = extern struct {
    /// Flags.
    flags: u16,
    /// Indicates where the driver would put the next descriptor entry in the ring.
    idx: u16,
    /// Ring of descriptor indices.
    __ring: void,

    pub fn ring(self: *const volatile PartialQueueAvail, idx: usize) u16 {
        return @as([*]const volatile u16, @ptrCast(&self.__ring))[idx];
    }
};

/// Virtqueue Used Ring.
///
/// This is where the device returns buffers once it is done with them.
const PartialQueueUsed = extern struct {
    /// Flags.
    flags: u16,
    /// Indicates where the device would put the next descriptor entry in the ring.
    idx: u16,
    /// Ring of used elements.
    __ring: void,

    const Elem = extern struct {
        /// Index of start of used descriptor chain.
        id: u32,
        /// The number of bytes written into the device writable portion of the buffer described by the descriptor chain.
        len: u32,
    };

    pub fn push(self: *volatile PartialQueueUsed, id: u32, len: u32, queue_size: u32) void {
        const ring = @as([*]volatile Elem, @ptrCast(@alignCast(&self.__ring)));
        ring[self.idx % queue_size] = .{ .id = id, .len = len };
        self.idx +%= 1;
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
const Fat32 = hugin.Fat32;
const Vblk = hugin.drivers.VirtioBlk;

const palloc = hugin.mem.page_allocator;
