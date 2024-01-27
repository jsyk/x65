# using llvm-mos compiler to generate .prg file loadable by CX16

CFLAGS=-Wall -Os

hello.rom: hello.c

# generate asm from C, for debug/inspection.
%.s: %.c
	mos-common-clang $(CFLAGS) -Wl,--lto-emit-asm $< -o $@

%.rom: %.c
	mos-common-clang $(CFLAGS) $< -o $@


clean:
	rm -f *.rom *.elf

# load to ROMBLOCK 0
load: hello.rom
	../../x65pyhost/do-loadbin.py hello.rom sram 0x080000

