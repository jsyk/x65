# Linker ld65 script for
# for SBL / ROM loader -> 
#   the PBL loads this into RAMBLOCK #191, which is just below ROMBLOCK #0,
#   and displays it in the RAMBANK.

# Memory sections
MEMORY
{
    ZEROPAGE:   start $0        size 256;
    STACK:      start $100      size 256;
    LOWRAM:     start $200      size 40192;
    IOREGS:     start $9F00     size 256;
    RAMBLOCK:    start $A000     size 8192 fill yes;
    ROMBLOCK:    start $C000     size 16384;
    ISAFIXROM:  start $07E100   size 8192;
}

SEGMENTS
{
    # Header at the beginning of the ROM:
    HEADER:     load = RAMBLOCK, type = ro, align = 8192;
    # ISAFIX abrt02 handler at offset $100, to be executed at $07E100:
    ISAFIX:     load = RAMBLOCK, run = ISAFIXROM, type = ro, align = $100;
    # The the rest:
    CODE:       load = RAMBLOCK, type = ro, align = $100;
    RODATA:     load = RAMBLOCK, type = ro;
    DATA:       load = LOWRAM, type = rw;
    BSS:        load = LOWRAM, type = bss, define = yes;
}
