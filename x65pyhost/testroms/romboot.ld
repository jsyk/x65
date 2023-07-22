# Linker ld65 script

# Memory sections
MEMORY
{
    ZEROPAGE:   start $0        size 256;
    STACK:      start $100      size 256;
    LOWRAM:     start $200      size 40192;
    IOREGS:     start $9F00     size 256;
    RAMBANK:    start $A000     size 8192;
    ROMBANK:    start $C000     size 16384;
}

SEGMENTS
{
    CODE:       load = ROMBANK, type = ro;
    RODATA:     load = ROMBANK, type = ro;
    LAST256:    load = ROMBANK, type = ro, offset = $3F00;
    VECTORS:    load = ROMBANK, type = ro, offset = $3FFA;
    DATA:       load = LOWRAM, type = rw;
    BSS:        load = LOWRAM, type = bss, define = yes;
}
