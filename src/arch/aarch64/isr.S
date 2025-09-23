.section  .text
.balign   0x800
.size     exception_table, 0x800
.global   exception_table
exception_table:

# Synchronous exceptions, Current Exception level with SP_EL0.
.balign 0x80
sync_curel_sp0:
  b sync_curel_sp0

# IRQ and vIRQ, Current Exception level with SP_EL0.
.balign 0x80
irq_curel_sp0:
  b irq_curel_sp0

# FIQ and vFIQ, Current Exception level with SP_EL0.
.balign 0x80
fiq_curel_sp0:
  b fiq_curel_sp0

# SError interrupts, Current Exception level with SP_EL0.
.balign 0x80
serror_curel_sp0:
  b serror_curel_sp0

# Synchronous exceptions, Current Exception level with SP_ELx.
.balign 0x80
sync_curel_spx:
  b sync_curel_spx

# IRQ and vIRQ, Current Exception level with SP_ELx.
.balign 0x80
irq_curel_spx:
  sub  sp,  sp, #(8 * 32)
  stp x30, xzr, [sp, #(15 * 16)]
  stp x28, x29, [sp, #(14 * 16)]
  stp x26, x27, [sp, #(13 * 16)]
  stp x24, x25, [sp, #(12 * 16)]
  stp x22, x23, [sp, #(11 * 16)]
  stp x20, x21, [sp, #(10 * 16)]
  stp x18, x19, [sp, #( 9 * 16)]
  stp x16, x17, [sp, #( 8 * 16)]
  stp x14, x15, [sp, #( 7 * 16)]
  stp x12, x13, [sp, #( 6 * 16)]
  stp x10, x11, [sp, #( 5 * 16)]
  stp  x8,  x9, [sp, #( 4 * 16)]
  stp  x6,  x7, [sp, #( 3 * 16)]
  stp  x4,  x5, [sp, #( 2 * 16)]
  stp  x2,  x3, [sp, #( 1 * 16)]
  stp  x0,  x1, [sp, #( 0 * 16)]
  mov  x0, sp
  adr x30, exit_exception
  b   irqHandler

# FIQ and vFIQ, Current Exception level with SP_ELx.
.balign 0x80
fiq_curel_spx:
  b fiq_curel_spx

# SError interrupts, Current Exception level with SP_ELx.
.balign 0x80
serror_curel_spx:
  b serror_curel_spx

# Synchronous exceptions, Lower Exception level with AArch64.
.balign 0x80
sync_lowerel_a64:
  sub  sp,  sp, #(8 * 32)
  stp x30, xzr, [sp, #(15 * 16)]
  stp x28, x29, [sp, #(14 * 16)]
  stp x26, x27, [sp, #(13 * 16)]
  stp x24, x25, [sp, #(12 * 16)]
  stp x22, x23, [sp, #(11 * 16)]
  stp x20, x21, [sp, #(10 * 16)]
  stp x18, x19, [sp, #( 9 * 16)]
  stp x16, x17, [sp, #( 8 * 16)]
  stp x14, x15, [sp, #( 7 * 16)]
  stp x12, x13, [sp, #( 6 * 16)]
  stp x10, x11, [sp, #( 5 * 16)]
  stp  x8,  x9, [sp, #( 4 * 16)]
  stp  x6,  x7, [sp, #( 3 * 16)]
  stp  x4,  x5, [sp, #( 2 * 16)]
  stp  x2,  x3, [sp, #( 1 * 16)]
  stp  x0,  x1, [sp, #( 0 * 16)]
  mov  x0, sp
  adr x30, exit_exception
  b   syncHandler

# IRQ and vIRQ, Lower Exception level with AArch64.
.balign 0x80
irq_lowerel_a64:
  sub  sp,  sp, #(8 * 32)
  stp x30, xzr, [sp, #(15 * 16)]
  stp x28, x29, [sp, #(14 * 16)]
  stp x26, x27, [sp, #(13 * 16)]
  stp x24, x25, [sp, #(12 * 16)]
  stp x22, x23, [sp, #(11 * 16)]
  stp x20, x21, [sp, #(10 * 16)]
  stp x18, x19, [sp, #( 9 * 16)]
  stp x16, x17, [sp, #( 8 * 16)]
  stp x14, x15, [sp, #( 7 * 16)]
  stp x12, x13, [sp, #( 6 * 16)]
  stp x10, x11, [sp, #( 5 * 16)]
  stp  x8,  x9, [sp, #( 4 * 16)]
  stp  x6,  x7, [sp, #( 3 * 16)]
  stp  x4,  x5, [sp, #( 2 * 16)]
  stp  x2,  x3, [sp, #( 1 * 16)]
  stp  x0,  x1, [sp, #( 0 * 16)]
  mov  x0, sp
  adr x30, exit_exception
  b   syncHandler

# FIQ and vFIQ, Lower Exception level with AArch64.
.balign 0x80
fiq_lowerel_a64:
  b fiq_lowerel_a64

# SError interrupts, Lower Exception level with AArch64.
.balign 0x80
serror_lowerel_a64:
  b serror_lowerel_a64

# Synchronous exceptions, Lower Exception level with AArch32.
.balign 0x80
sync_lowerel_a32:
  b sync_lowerel_a32

# IRQ and vIRQ, Lower Exception level with AArch32.
.balign 0x80
irq_lowerel_a32:
  b irq_lowerel_a32

# FIQ and vFIQ, Lower Exception level with AArch32.
.balign 0x80
fiq_lowerel_a32:
  b fiq_lowerel_a32

# SError interrupts, Lower Exception level with AArch32.
.balign 0x80
serror_lowerel_a32:
  b serror_lowerel_a32

exit_exception:
  ldp x30, xzr, [sp, #(15 * 16)]
  ldp x28, x29, [sp, #(14 * 16)]
  ldp x26, x27, [sp, #(13 * 16)]
  ldp x24, x25, [sp, #(12 * 16)]
  ldp x22, x23, [sp, #(11 * 16)]
  ldp x20, x21, [sp, #(10 * 16)]
  ldp x18, x19, [sp, #( 9 * 16)]
  ldp x16, x17, [sp, #( 8 * 16)]
  ldp x14, x15, [sp, #( 7 * 16)]
  ldp x12, x13, [sp, #( 6 * 16)]
  ldp x10, x11, [sp, #( 5 * 16)]
  ldp  x8,  x9, [sp, #( 4 * 16)]
  ldp  x6,  x7, [sp, #( 3 * 16)]
  ldp  x4,  x5, [sp, #( 2 * 16)]
  ldp  x2,  x3, [sp, #( 1 * 16)]
  ldp  x0,  x1, [sp, #( 0 * 16)]
  add  sp,  sp, #(8 * 32)
  eret
