
INCLUDES = -I../../include



all: sbl.bin

sbl.bin: vt.o font8x8.o romstru.o
	ld65 -C romboot.ld $^ -o $@

sbl.lst: vt.s


%.bin: %.o
	ld65 -C romboot.ld $< -o $@

%.o: %.s
	ca65 $(INCLUDES) --cpu 65c02  $<

%.lst: %.s
	ca65 $(INCLUDES) --cpu 65c02 $< -l $@

load_sbl: sbl.bin
	echo "Loading sbl.bin to 0x080000 (ROMBANK 0)"
	../../x65pyhost/do-loadbin.py sbl.bin sram 0x080000
	# ./do-cpureset.py -r 0

