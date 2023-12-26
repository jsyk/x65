# using llvm-mos compiler to generate .prg file loadable by CX16

CFLAGS=-Wall -O1
PRG=mtest.prg

$(PRG): mtest.c

%.prg: %.c
	mos-cx16-clang $(CFLAGS) $< -o $@

clean:
	rm -f *.prg *.elf

load: $(PRG)
	../../x65pyhost/do-loadprg.py $(PRG)
	@echo "Now type RUN in CX16 prompt!"
