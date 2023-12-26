# using llvm-mos compiler to generate .prg file loadable by CX16

CFLAGS=-O1

hello.prg: hello.c

%.prg: %.c
	mos-cx16-clang $(CFLAGS) $< -o $@

clean:
	rm -f *.prg *.elf

load: hello.prg
	../../x65pyhost/do-loadprg.py hello.prg
	@echo "Now type RUN in CX16 prompt!"
