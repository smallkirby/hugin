OUTPUT_FORMAT(elf64-aarch64)
ENTRY(main)

_ALIGN_SIZE = 0x1000;
_RAM_BASE   = 0x40400000;

SECTIONS {
  . = _RAM_BASE + SIZEOF_HEADERS;

  .text : ALIGN(_ALIGN_SIZE) {
    *(.text .text.*)
  }

  .data : ALIGN(_ALIGN_SIZE) {
    *(.data .data.*)
  }

  .rodata : ALIGN(_ALIGN_SIZE) {
    *(.rodata .rodata.*)
  }

  .bss : ALIGN(_ALIGN_SIZE) {
    *(.bss .bss.*)
  }

  .got : ALIGN(_ALIGN_SIZE) {
    *(.got .got.*)
  }
}
