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
    ISAFIXROM:  start $07E000   size 8192;
}

SEGMENTS
{
    CODE:       load = ISAFIXROM, type = ro;
    RODATA:     load = ISAFIXROM, type = ro;
    DATA:       load = LOWRAM, type = rw;
    BSS:        load = LOWRAM, type = bss, define = yes;
}
