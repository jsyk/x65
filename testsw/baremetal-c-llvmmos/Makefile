# using llvm-mos compiler to generate .prg file loadable by CX16

CFLAGS=-Wall -Os

all: hello.rom mtestb.rom

hello.rom: hello.c
hello.s: hello.c
mtestb.rom: mtestb.c


# generate asm from C, for debug/inspection.
%.s: %.c
	mos-common-clang $(CFLAGS) -Wl,--lto-emit-asm $< -o $@

%.rom: %.c
	mos-common-clang $(CFLAGS) $< -o $@


clean:
	rm -f *.rom *.elf

# load to ROMBLOCK 0
load_hello: hello.rom
	../../x65pyhost/do-loadbin.py $< sram 0x080000

load_mtestb: mtestb.rom
	../../x65pyhost/do-loadbin.py $< sram 0x080000
