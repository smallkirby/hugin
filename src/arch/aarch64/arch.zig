/// Halt until interrupt.
pub fn halt() void {
    asm volatile ("wfi");
}
