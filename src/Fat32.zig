const Self = @This();
pub const Fat32 = Self;

pub const Error = error{
    /// MBR is invalid.
    InvalidBootSector,
    /// Target resource not found.
    NotFound,
} || VirtioBlk.Error;

/// Type of Logical Block Address.
const Lba = u32;

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
    root_clus: u32 align(1),
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

/// Find a FAT32 filesystem from the given Virtio Block Device.
pub fn from(vblk: *VirtioBlk) Error!Self {
    const start_lba = try Mbr.getPartition(vblk, .fat32_lba);

    return new(vblk, start_lba, 512);
}

/// Initialize a FAT32 filesystem instance.
fn new(vblk: *VirtioBlk, base: Lba, comptime lbasize: usize) Error!Self {
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
    log.debug("   Media     : 0x{X}", .{bpb.media});
    log.debug("   #FATs     : {d}", .{bpb.num_fats});
    log.debug("   #Sectors  : {d}", .{bpb.tot_sec32});
    if (bpb.boot_sig == Bpb.valid_boot_sig) {
        log.debug("   Vol ID    : 0x{X}", .{bpb.vol_id});
        log.debug("   Vol Label : {s}", .{bpb.vol_lab});
        log.debug("   Signature : {s}", .{bpb.fil_sys_type});
    }

    hugin.unimplemented("Fat32.new");
}

// =============================================================
// Imports
// =============================================================

const std = @import("std");
const log = std.log.scoped(.fat32);
const hugin = @import("hugin");
const VirtioBlk = hugin.drivers.VirtioBlk;
