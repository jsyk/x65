# using llvm-mos compiler to generate .prg file loadable by CX16

CFLAGS=-Wall -Os

all: hello.rom mtestb.rom vchartst.rom termdemo.rom

hello.rom: hello.c
hello.s: hello.c
mtestb.rom: mtestb.c

vchartst.rom: vchartst.c font8x8.c
	mos-common-clang $(CFLAGS) vchartst.c font8x8.c -o $@

termdemo.rom: termdemo.c font8x8.c
	mos-common-clang $(CFLAGS) termdemo.c font8x8.c -o $@

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

load_vchartst: vchartst.rom
	../../x65pyhost/do-loadbin.py $< sram 0x080000

load_termdemo: termdemo.rom
	../../x65pyhost/do-loadbin.py $< sram 0x080000
