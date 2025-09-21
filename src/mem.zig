/// KiB in bytes.
pub const kib = 1024;
/// MiB in bytes.
pub const mib = 1024 * kib;
/// GiB in bytes.
pub const gib = 1024 * mib;

/// Size of a single page in bytes in Norn kernel.
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
