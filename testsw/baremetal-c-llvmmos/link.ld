/* 
 */

__basic_zp_start = 0x0002;
__basic_zp_end = 0x0080;

MEMORY {
    ram (rw) : ORIGIN = 0x0200, LENGTH = 0x9D00
    rom (r) : ORIGIN = 0xC000, LENGTH = 0x3FE0
    vectors (r) : ORIGIN = 0xFFE0, LENGTH = 0x20
}

/* INCLUDE commodore.ld */

/* Provide imaginary (zero page) registers in the BASIC area. */
__rc0 = __basic_zp_start;
INCLUDE imag-regs.ld
/* No assertion - cx16 uses a non-contiguous imaginary register block larger than 32 bytes. */

MEMORY { zp : ORIGIN = __rc31 + 1, LENGTH = __basic_zp_end - (__rc31 + 1) }

/* INPUT(basic-header.o) */

REGION_ALIAS("c_readonly", rom)
REGION_ALIAS("c_writeable", ram)

SECTIONS {
    /* BASIC program that jumps to _start. */
    /* .basic_header : { *(.basic_header) } */

    INCLUDE c.ld
}


/* Set initial soft stack address to end of BASIC area. (It grows down.) */
__stack = 0x9f00;

OUTPUT_FORMAT {
    /* Tells the LOAD command where to place the file's contents. */
    /* SHORT(ORIGIN(ram)) */
    /* TRIM(rom) */
    FULL(rom)
    /* FULL(vectors) */
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)

    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
    SHORT(_start)
}
