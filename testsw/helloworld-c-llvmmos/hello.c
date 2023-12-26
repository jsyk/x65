/**
 * Minimal HELLO WORLD, in 6502 mode.
 * Compiler: llvm-mos, generates .prg file
 * Can be loaded through ICD do-loadprg.py directly into CX16 running system.
*/
#include <stdio.h>

int main()
{
    printf("HELLO WORLD FROM C!\r\n");
    return 0;
}
