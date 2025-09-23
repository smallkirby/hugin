/// Errors.
pub const MemError = error{
    /// Out of memory.
    OutOfMemory,
    /// Virtual memory allocation failed.
    OutOfVirtualMemory,
    /// The specified region is invalid.
    InvalidRegion,
};

pub const PageAllocator = @import("mem/PageAllocator.zig");

/// Physical address.
pub const Phys = u64;
/// Virtual address.
pub const Virt = u64;
/// Physical memory region.
pub const PhysRegion = struct {
    addr: Phys,
    size: usize,
};

/// KiB in bytes.
pub const kib = 1024;
/// MiB in bytes.
pub const mib = 1024 * kib;
/// GiB in bytes.
pub const gib = 1024 * mib;

/// Size of a single page in bytes in Hugin kernel.
pub const page_size: u64 = size_4kib;
/// Number of bits to shift to extract the PFN from physical address.
pub const page_shift: u64 = page_shift_4kib;
/// Bit mask to extract the page-aligned address.
pub const page_mask: u64 = page_mask_4kib;

/// Size in bytes of a 4KiB.
pub const size_4kib = 4 * kib;
/// Size in bytes of a 2MiB.
pub const size_2mib = size_4kib << 9;
/// Size in bytes of a 1GiB.
pub const size_1gib = size_2mib << 9;
/// Shift in bits for a 4K page.
pub const page_shift_4kib = 12;
/// Shift in bits for a 2M page.
pub const page_shift_2mib = 21;
/// Shift in bits for a 1G page.
pub const page_shift_1gib = 30;
/// Mask for a 4K page.
pub const page_mask_4kib: u64 = size_4kib - 1;
/// Mask for a 2M page.
pub const page_mask_2mib: u64 = size_2mib - 1;
/// Mask for a 1G page.
pub const page_mask_1gib: u64 = size_1gib - 1;

/// General memory allocator.
pub const general_allocator = bin_allocator_instance.getAllocator();
/// General page allocator that can be used to allocate physically contiguous pages.
pub const page_allocator = buddy_allocator_instance.getAllocator();

/// One and only instance of the buddy allocator.
var buddy_allocator_instance = BuddyAllocator.new();
const BuddyAllocator = @import("mem/BuddyAllocator.zig");
/// One and only instance of the bin allocator.
var bin_allocator_instance = BinAllocator.newUninit();
const BinAllocator = @import("mem/BinAllocator.zig");

/// Initialize allocators
pub fn initAllocators(avail: PhysRegion, reserveds: []PhysRegion, log_fn: hugin.klog.LogFn) void {
    buddy_allocator_instance.init(avail, reserveds, log_fn);
    bin_allocator_instance.init(buddy_allocator_instance.getAllocator());
}

/// Translate the given virtual address to physical address.
///
/// This function just use simple calculation and does not walk page tables.
/// To do page table walk, use arch-specific functions.
pub fn virt2phys(addr: anytype) Phys {
    const value = switch (@typeInfo(@TypeOf(addr))) {
        .int, .comptime_int => @as(u64, addr),
        .pointer => |p| switch (p.size) {
            .one, .many => @as(u64, @intFromPtr(addr)),
            .slice => @as(u64, @intFromPtr(addr.ptr)),
            else => @panic("virt2phys: invalid type"),
        },
        else => @compileError("virt2phys: invalid type"),
    };

    return value;
}

/// Translate the given physical address to virtual address.
///
/// This function just use simple calculation and does not walk page tables.
/// To do page table walk, use arch-specific functions.
pub fn phys2virt(addr: anytype) Virt {
    const value = switch (@typeInfo(@TypeOf(addr))) {
        .int, .comptime_int => @as(u64, addr),
        .pointer => @as(u64, @intFromPtr(addr)),
        else => @compileError("phys2virt: invalid type"),
    };

    return value;
}

// =============================================================
// Tests
// =============================================================

test {
    _ = BuddyAllocator;
    _ = BinAllocator;
}

// =============================================================
// Imports
// =============================================================

const hugin = @import("hugin");
