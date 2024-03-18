# Linker ld65 script

# Memory sections
MEMORY
{
    ZEROPAGE:   start $0        size 256;
    STACK:      start $100      size 256;
    LOWRAM:     start $200      size 40192;
    IOREGS:     start $9F00     size 256;
    RAMBANK:    start $A000     size 8192;
    BOOTROM:    start $FE00     size 512;
}

SEGMENTS
{
    CODE:       load = BOOTROM, type = ro;
    RODATA:     load = BOOTROM, type = ro;
    VECTORS:    load = BOOTROM, type = ro, offset = $1FA;
    DATA:       load = LOWRAM, type = rw;
    BSS:        load = LOWRAM, type = bss, define = yes;
}
