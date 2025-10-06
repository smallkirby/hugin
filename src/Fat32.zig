const Self = @This();
pub const Fat32 = Self;

pub const Error = error{
    /// MBR is invalid.
    InvalidBootSector,
    /// Target resource not found.
    NotFound,
    /// Invalid argument.
    InvalidArgument,
    /// Failed to iterate cluster chain.
    ClusterNotFound,
} || VirtioBlk.Error || PageAllocator.Error;

/// Underlying Virtio Block Device.
vblk: *VirtioBlk,
/// Base LBA of the FAT32 filesystem.
base: Lba,
/// Block size in bytes of the underlying block device.
lbasize: usize,
/// Bytes per sector.
bytes_per_sec: u16,
/// Sectors per cluster.
sec_per_clus: u8,
/// Number of reserved sectors.
rsvd_sec_cnt: u16,
/// Size in sectors of one FAT.
fat_sz32: u32,
/// Number of FATs.
num_fats: u8,
/// Pointer to the first FAT.
fat: []u8,
/// Pointer to the root directory entries.
rdents: []u8,

/// Type of Logical Block Address.
const Lba = u32;
/// Index of a cluster.
const Cluster = u32;
/// Index of a sector.
const Sector = u32;

/// FAT32 filesystem signature in Boot Sector.
const fat32_signature = "FAT32   ";

/// Master Boot Record (MBR).
const Mbr = struct {
    /// Number of partition table entries.
    const num_ptentries = 4;
    /// Valid bootsector signature in little-endian.
    const valid_signature = [2]u8{ 0x55, 0xAA };
    /// MBR size in bytes.
    const size_mbr = 512;
    /// Size in bytes of the bootstrap area.
    const size_bootstrap = 446;
    /// Offset of the partition table entries.
    const pos_ptentries = size_bootstrap;
    /// Offset of the signature.
    const pos_signature = 0x1FE;

    /// MBR Partition table entry.
    const PtEntry = extern struct {
        /// Drive attributes.
        attr: Attr,
        /// CHS (Cylinder-Head-Sector) address of the first partition.
        start_chs: [3]u8,
        /// Type of partition.
        type: Type,
        /// CHS address of the last partition.
        last_chs: [3]u8,
        /// LBA of the first sector of the partition.
        start_lba: Lba,
        /// Number of sectors in the partition.
        num_sectors: u32,

        /// Drive attributes.
        const Attr = enum(u8) {
            inactive = 0x00,
            active = 0x80,
        };

        /// Partition type.
        const Type = enum(u8) {
            /// FAT32 with LBA.
            fat32_lba = 0x0C,

            _,
        };
    };

    /// Type of partition table.
    const Ptable = [num_ptentries]PtEntry;

    /// Parse MBR's partition table entries and returns the start LBA.
    pub fn getPartition(vblk: *VirtioBlk, pttype: PtEntry.Type) Error!Lba {
        var buffer: [size_mbr]u8 = undefined;
        try vblk.read(buffer[0..], 0);

        const signature = buffer[pos_signature .. pos_signature + 2];
        if (!std.mem.eql(u8, &valid_signature, signature)) {
            return Error.InvalidBootSector;
        }

        const ptentries: *align(1) const Ptable = @ptrCast(&buffer[pos_ptentries]);
        for (ptentries) |*entry| {
            if (entry.type == pttype) {
                return entry.start_lba;
            }
        }

        return Error.NotFound;
    }
};

/// Boot Parameter Block (BPB) in a Boot Sector of FAT32.
const Bpb = extern struct {
    /// Valid boot sector signature.
    const valid_boot_sig = 0x29;

    /// Jump instruction to boot code.
    jmpboot: [3]u8 align(1),
    /// OEM Name in ASCII.
    oemname: [8]u8 align(1),
    /// Count of bytes per sector.
    bytes_per_sec: u16 align(1),
    /// Number of sectors per allocation unit.
    sec_per_clus: u8 align(1),
    /// Number of reserved sectors in the Reserved region of the volume.
    rsvd_sec_cnt: u16 align(1),
    /// The count of FAT data structures on the volume. Always 2 for FAT32.
    num_fats: u8 align(1),
    /// Must be 0 for FAT32.
    root_ent_cnt: u16 align(1),
    /// Must be 0 for FAT32.
    tot_sec16: u16 align(1),
    /// Media type.
    media: u8 align(1),
    /// Must be 0 for FAT32.
    fat_sz16: u16 align(1),
    /// Sectors per track for interrupt 0x13.
    sec_per_trk: u16 align(1),
    /// Number of heads for interrupt 0x13.
    num_heads: u16 align(1),
    /// Count of hidden sectors preceding the partition that contains this FAT volume.
    hidd_sec: u32 align(1),
    /// Count of sectors on the volume.
    tot_sec32: u32 align(1),

    /// Count of sectors occupied by ONE FAT data structure.
    fat_sz32: u32 align(1),
    /// Flags.
    ext_flags: u16 align(1),
    /// Revision number.
    fs_ver: u16 align(1),
    /// Cluster number of the first cluster of the root directory.
    root_clus: Cluster align(1),
    /// Sector number of the FSInfo structure in the reserved area of the FAT32 volume.
    fs_info: u16 align(1),
    /// Sector number of the copy of the boot record.
    bk_boot_sec: u16 align(1),
    /// Must be 0 for FAT32.
    reserved: [12]u8 align(1),
    /// Int 0x13 drive number.
    drv_num: u8 align(1),
    /// Reserved.
    reserved1: u8 align(1),
    /// Extended boot signature to identify if the next three fields are valid.
    boot_sig: u8 align(1),
    /// Volume serial number.
    vol_id: u32 align(1),
    /// Volume label in ASCII.
    vol_lab: [11]u8 align(1),
    /// Always "FAT32   ".
    fil_sys_type: [8]u8 align(1),

    comptime {
        const size = @bitSizeOf(Bpb);
        const expected = 90 * @bitSizeOf(u8);
        hugin.comptimeAssert(
            size == expected,
            "Invalid size of BPB: expected {d} bits, found {d} bits",
            .{ expected, size },
        );
    }
};

/// FAT32 Directory Entry.
const DirEntry = extern struct {
    /// Short name.
    name: [8]u8 align(1),
    /// Extension of the short name.
    ext: [3]u8 align(1),
    /// File attributes.
    attr: Attr,
    /// Reserved.
    ntres: u8,
    /// Millisecond stamp at file creation time (a count of tenths of a second).
    crt_time_tenth: u8,
    /// Time file was created.
    crt_time: u16 align(1),
    /// Date file was created.
    crt_date: u16 align(1),
    /// Last access date.
    lstacc_date: u16 align(1),
    /// High word of this entry's first cluster number.
    fstclus_hi: u16 align(1),
    /// Time of last write.
    wrt_time: u16 align(1),
    /// Date of last write.
    wrt_date: u16 align(1),
    /// Low word of this entry's first cluster number.
    fstclus_lo: u16 align(1),
    /// File size in bytes.
    size: u32 align(1),

    const Attr = packed struct(u8) {
        /// Read Only.
        read_only: bool,
        /// Hidden.
        hidden: bool,
        /// System.
        system: bool,
        /// Volume ID.
        volume_id: bool,
        /// Directory.
        directory: bool,
        /// Archive.
        archive: bool,
        /// Reserved.
        _reserved: u2 = 0,
    };

    /// Check if this entry is a long filename entry.
    pub fn longname(self: DirEntry) bool {
        const attr = self.attr;
        return attr.read_only and attr.hidden and attr.system and attr.volume_id;
    }

    /// Check if this entry is free.
    pub fn free(self: DirEntry) bool {
        return self.name[0] == 0xE5;
    }

    /// Check if this entry is free and there're no allocated entries after this.
    pub fn sentinel(self: DirEntry) bool {
        return self.name[0] == 0x00;
    }

    /// Get the name of this entry.
    pub fn getName(self: DirEntry, buf: []u8) Error![]const u8 {
        if (self.longname()) {
            return Error.InvalidArgument;
        }

        // Name part.
        buf[0] = if (self.name[0] == 0x05) 0xE5 else self.name[0];
        var cur: usize = 1;
        for (self.name[1..]) |c| {
            if (c == ' ') continue;
            buf[cur] = c;
            cur += 1;
        }

        // Extension part.
        if (self.ext[0] != ' ') {
            buf[cur] = '.';
            cur += 1;
        }
        for (self.ext) |c| {
            if (c == ' ') continue;
            buf[cur] = c;
            cur += 1;
        }

        return buf[0..cur];
    }

    /// Get the first cluster number of this entry.
    pub fn getFirstCluster(self: DirEntry) Cluster {
        return hugin.bits.concat(Cluster, self.fstclus_hi, self.fstclus_lo);
    }

    comptime {
        const size = @bitSizeOf(DirEntry);
        const expected = 32 * @bitSizeOf(u8);
        hugin.comptimeAssert(
            size == expected,
            "Invalid size of DirEntry: expected {d} bits, found {d} bits",
            .{ expected, size },
        );
    }
};

/// Find a FAT32 filesystem from the given Virtio Block Device.
pub fn from(vblk: *VirtioBlk, palloc: PageAllocator) Error!Self {
    const start_lba = try Mbr.getPartition(vblk, .fat32_lba);

    return new(vblk, start_lba, 512, palloc);
}

/// Initialize a FAT32 filesystem instance.
fn new(vblk: *VirtioBlk, base: Lba, comptime lbasize: usize, palloc: PageAllocator) Error!Self {
    // Read BPB.
    var bpbbuf: [lbasize]u8 align(@alignOf(Bpb)) = undefined;
    @memset(bpbbuf[0..], 0);
    const bpb: *const Bpb = @ptrCast(@alignCast(&bpbbuf));
    try vblk.read(bpbbuf[0..], base * lbasize);

    // Debug print BPB info.
    log.debug("Found FAT32 filesystem @ LBA=0x{X}", .{base});
    log.debug("   OEM       : {s}", .{bpb.oemname});
    log.debug("   Revision  : {d}.{d}", .{ bpb.fs_ver >> 8, bpb.fs_ver & 0xFF });
    log.debug("   Root Clus : {d}", .{bpb.root_clus});
    log.debug("   Bytes/sec : {d}", .{bpb.bytes_per_sec});
    log.debug("   Sec/Clus  : {d}", .{bpb.sec_per_clus});
    log.debug("   Media     : 0x{X}", .{bpb.media});
    log.debug("   Rsvd Secs : {d}", .{bpb.rsvd_sec_cnt});
    log.debug("   #FATs     : {d}", .{bpb.num_fats});
    log.debug("   FAT Sz    : {d}", .{bpb.fat_sz32});
    log.debug("   #Sectors  : {d}", .{bpb.tot_sec32});
    if (bpb.boot_sig == Bpb.valid_boot_sig) {
        log.debug("   Vol ID    : 0x{X}", .{bpb.vol_id});
        log.debug("   Vol Label : {s}", .{bpb.vol_lab});
        log.debug("   Signature : {s}", .{bpb.fil_sys_type});
    }

    // Validate BPB.
    if (bpb.boot_sig != Bpb.valid_boot_sig) {
        return Error.InvalidBootSector;
    }
    if (!std.mem.eql(u8, &bpb.fil_sys_type, fat32_signature)) {
        return Error.InvalidBootSector;
    }

    // Read the first FAT (more than one FAT is not supported yet).
    const fat_size = bpb.fat_sz32 * bpb.bytes_per_sec;
    const lba_fat_size = hugin.bits.roundup(fat_size, lbasize);
    const fat = try palloc.allocPages(lba_fat_size >> hugin.mem.page_shift);
    errdefer palloc.freePages(fat);

    const fat_addr = base * lbasize + bpb.rsvd_sec_cnt * bpb.bytes_per_sec;
    try vblk.read(fat[0..lba_fat_size], fat_addr);

    const rdents_size = hugin.bits.roundup(bpb.sec_per_clus * bpb.bytes_per_sec, hugin.mem.page_size);
    const rdents_buf = try palloc.allocPages(rdents_size >> hugin.mem.page_shift);
    errdefer palloc.freePages(rdents_buf);

    const self = Self{
        .vblk = vblk,
        .base = base,
        .lbasize = lbasize,
        .bytes_per_sec = bpb.bytes_per_sec,
        .sec_per_clus = bpb.sec_per_clus,
        .rsvd_sec_cnt = bpb.rsvd_sec_cnt,
        .fat_sz32 = bpb.fat_sz32,
        .num_fats = bpb.num_fats,
        .fat = fat,
        .rdents = rdents_buf,
    };

    // Read root directory.
    const root_sec = self.clus2sec(bpb.root_clus);
    try self.readSectors(rdents_buf, root_sec, self.sec_per_clus);

    // Debug print root directory entries.
    {
        log.debug("List of files:", .{});
        var namebuf: [13]u8 = undefined;

        var iter = FileIter.new(self.getRdents());
        while (iter.next()) |dent| {
            const name = try dent.getName(&namebuf);
            log.debug("   {s: <11} ({d} bytes)", .{ name, dent.size });
        }
    }

    return self;
}

/// Information about a file.
pub const FileInfo = struct {
    /// Number of the first cluster of the file.
    cluster: Cluster,
    /// File size in bytes.
    size: u32,
};

/// Read a file described by `file` into `buffer` starting from `offset`.
///
/// - `file`: Information about the file to read.
/// - `buffer`: Buffer to read into. The buffer does not have to be aligned.
/// - `offset`: Offset in bytes from the beginning of the file to start reading.
/// - `palloc`: Page allocator to allocate internal buffers.
///
/// Returns the number of bytes read.
/// If the end of the file is reached before filling the buffer, the number of bytes read will be less than `buffer.len`.
pub fn read(self: Self, file: FileInfo, buffer: []u8, offset: usize, palloc: PageAllocator) Error!usize {
    const size = if (file.size <= offset + buffer.len) blk: {
        if (file.size <= offset) return 0;
        break :blk file.size - offset;
    } else buffer.len;

    const bytes_per_clus = self.sec_per_clus * self.bytes_per_sec;
    const clus_to_skip = offset / bytes_per_clus;
    var bytes_skipped: usize = 0;

    // Allocate an aligned buffer for reading all sectors in a cluster.
    const tmpbuf_size = hugin.bits.roundup(bytes_per_clus, hugin.mem.page_size);
    const tmpbuf = try palloc.allocPages(
        hugin.bits.roundup(tmpbuf_size, hugin.mem.page_size) >> hugin.mem.page_shift,
    );
    defer palloc.freePages(tmpbuf);

    // Skip clusters for offset.
    var iter = ClusterIter.new(self.fat, file.cluster);
    for (0..clus_to_skip) |_| {
        if (iter.next() == null) {
            return Error.InvalidArgument;
        }
        bytes_skipped += bytes_per_clus;
    }

    // Read clusters.
    var num_read: usize = 0;
    while (iter.next()) |clus| {
        // Read all sectors in the cluster.
        try self.readSectors(
            tmpbuf,
            self.clus2sec(clus),
            self.sec_per_clus,
        );

        // Copy data to the user buffer.
        const sec_offset = if (bytes_skipped < offset) blk: {
            const ret = offset - bytes_skipped;
            bytes_skipped = offset;
            break :blk ret;
        } else 0;
        const size_to_copy = @min(size - num_read, bytes_per_clus - sec_offset);
        @memcpy(
            buffer[num_read .. num_read + size_to_copy],
            tmpbuf[sec_offset .. sec_offset + size_to_copy],
        );

        num_read += size_to_copy;
        if (num_read >= size) {
            break;
        }
    }

    hugin.rtt.expectEqual(size, num_read);
    return num_read;
}

/// Write a file described by `file` from `buffer` starting from `offset`.
///
/// - `file`: Information about the file to write.
/// - `buffer`: Buffer to write from. The buffer does not have to be aligned.
/// - `offset`: Offset in bytes from the beginning of the file to start writing.
/// - `palloc`: Page allocator to allocate internal buffers.
///
/// Returns the number of bytes written.
/// If the end of the file is reached before writing all data, the number of bytes written will be less than `buffer.len`.
pub fn write(self: Self, file: FileInfo, buffer: []u8, offset: usize, palloc: PageAllocator) Error!usize {
    const size = if (file.size <= offset + buffer.len) blk: {
        if (file.size <= offset) return 0;
        break :blk file.size - offset;
    } else buffer.len;

    const bytes_per_clus = self.sec_per_clus * self.bytes_per_sec;
    const clus_to_skip = offset / bytes_per_clus;
    var bytes_skipped: usize = 0;

    // Allocate an aligned buffer for reading all sectors in a cluster.
    const tmpbuf_size = hugin.bits.roundup(bytes_per_clus, hugin.mem.page_size);
    const tmpbuf = try palloc.allocPages(
        hugin.bits.roundup(tmpbuf_size, hugin.mem.page_size) >> hugin.mem.page_shift,
    );
    defer palloc.freePages(tmpbuf);

    // Skip clusters for offset.
    var iter = ClusterIter.new(self.fat, file.cluster);
    for (0..clus_to_skip) |_| {
        if (iter.next() == null) {
            return Error.InvalidArgument;
        }
        bytes_skipped += bytes_per_clus;
    }

    // Write to clusters.
    var num_written: usize = 0;
    while (iter.next()) |clus| {
        // Read all sectors in the cluster.
        try self.readSectors(
            tmpbuf,
            self.clus2sec(clus),
            self.sec_per_clus,
        );

        // Copy data from the user buffer.
        const sec_offset = if (bytes_skipped < offset) blk: {
            const ret = offset - bytes_skipped;
            bytes_skipped = offset;
            break :blk ret;
        } else 0;
        const size_to_copy = @min(size - num_written, bytes_per_clus - sec_offset);
        @memcpy(
            tmpbuf[sec_offset .. sec_offset + size_to_copy],
            buffer[num_written .. num_written + size_to_copy],
        );

        // Write all sectors in the cluster.
        try self.writeSectors(
            tmpbuf,
            self.clus2sec(clus),
            self.sec_per_clus,
        );

        num_written += size_to_copy;
        if (num_written >= size) {
            break;
        }
    }

    hugin.rtt.expectEqual(size, num_written);
    return num_written;
}

/// Find a file by its name.
///
/// LFN (Long File Name) entries are not supported.
pub fn lookup(self: Self, name: []const u8) Error!?FileInfo {
    if (name.len > 12) {
        return null;
    }

    var namebuf: [13]u8 = undefined;
    var targetbuf: [13]u8 = undefined;
    const target = std.ascii.lowerString(targetbuf[0..], name);

    var iter = FileIter.new(self.getRdents());
    while (iter.next()) |dent| {
        const dent_name = try dent.getName(&namebuf);
        const ldent_name = std.ascii.lowerString(namebuf[0..], dent_name);

        if (std.mem.eql(u8, target, ldent_name)) {
            return FileInfo{
                .cluster = dent.getFirstCluster(),
                .size = dent.size,
            };
        }
    }

    return null;
}

/// Convert cluster number to sector number.
fn clus2sec(self: Self, clus: Cluster) Sector {
    return (clus - 2) * self.sec_per_clus + self.rsvd_sec_cnt + @as(Cluster, self.num_fats) * self.fat_sz32;
}

/// Read `count` sectors starting from `sec` into `buffer`.
fn readSectors(self: Self, buffer: []u8, sec: Sector, count: u32) Error!void {
    const addr = (self.base * self.lbasize) + (sec * self.bytes_per_sec);
    const size = count * self.bytes_per_sec;
    if (buffer.len < size) {
        return Error.InvalidArgument;
    }

    return self.vblk.read(buffer, addr);
}

/// Write `count` sectors starting from `sec` from `buffer`.
fn writeSectors(self: Self, buffer: []const u8, sec: Sector, count: u32) Error!void {
    const addr = (self.base * self.lbasize) + (sec * self.bytes_per_sec);
    const size = count * self.bytes_per_sec;
    if (buffer.len < size) {
        return Error.InvalidArgument;
    }

    return self.vblk.write(buffer, addr);
}

/// Get root directory entries.
fn getRdents(self: Self) []const DirEntry {
    const rdents_len = self.sec_per_clus * self.bytes_per_sec / @sizeOf(DirEntry);
    const rdents: [*]align(1) const DirEntry = @ptrCast(@alignCast(self.rdents.ptr));
    return rdents[0..rdents_len];
}

/// Iterator over cluster chain.
const ClusterIter = struct {
    /// FAT entries.
    fat: []const Cluster,
    /// Current cluster number.
    cur: Cluster,

    /// Create a new cluster iterator starting from `start`-th sector.
    ///
    /// The first `next()` call returns `start`.
    pub fn new(fat: []u8, start: Cluster) ClusterIter {
        hugin.rtt.expectEqual(0, fat.len % @sizeOf(Cluster));

        const fatp: [*]const Cluster = @ptrCast(@alignCast(fat.ptr));

        return ClusterIter{
            .fat = fatp[0 .. fat.len / @sizeOf(Cluster)],
            .cur = start,
        };
    }

    /// Get the next cluster number.
    pub fn next(self: *ClusterIter) ?Cluster {
        if (self.cur < 2 or self.cur >= 0x0FFFFFF8) {
            return null;
        }

        const nextc = self.fat[self.cur];
        const ret = self.cur;
        self.cur = nextc;

        return ret;
    }
};

/// Iterator over files in the root directory entries.
const FileIter = struct {
    /// Root directory entries.
    rdents: []const DirEntry,
    /// Current index.
    cur: usize,

    pub fn new(rdents: []const DirEntry) FileIter {
        return FileIter{
            .rdents = rdents,
            .cur = 0,
        };
    }

    pub fn next(self: *FileIter) ?*const DirEntry {
        while (self.cur < self.rdents.len) {
            const dent = &self.rdents[self.cur];
            self.cur += 1;

            if (dent.longname()) {
                continue; // not supported.
            }
            if (dent.attr.directory) {
                continue; // not supported.
            }
            if (dent.attr.volume_id) {
                continue; // volume label entry.
            }
            if (dent.free()) {
                continue; // free entry.
            }
            if (dent.sentinel()) {
                return null; // end of entries.
            }

            return dent;
        }

        return null;
    }
};

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.fat32);
const hugin = @import("hugin");
const PageAllocator = hugin.mem.PageAllocator;
const VirtioBlk = hugin.drivers.VirtioBlk;
