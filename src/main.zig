export fn main() callconv(.c) noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}
