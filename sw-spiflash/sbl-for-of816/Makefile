
OF816ROM=of816-x65.bin
INCLUDES = -I../../include -I.


# All the targets for the complete build
all: sbl.bin sbl.lst isafix.lst trampoline.lst img.bin

# Complete image file is composed from the SBL and the OF816ROM as the payload
img.bin: sbl.bin bios.bin $(OF816ROM)
	cat sbl.bin bios.bin $(OF816ROM) >img.bin

bios.bin : vt.o bios.o kbd_table.o kbd.o
	ld65 -C bios.ld $^ -o $@ --mapfile bios.map

sbl.bin: ../common/sbl.o ../common/isafix.o ../common/vidtext.o ../common/font8x8.o
	ld65 -C ../common/sbl.ld $^ -o $@

sbl.lst: vt.s


# %.bin: %.o
# ld65 -C romboot.ld $< -o $@

%.o: %.s
	ca65 $(INCLUDES) --cpu 65c02  $<

%.lst: %.s
	ca65 $(INCLUDES) --cpu 65c02 $< -l $@

%.o: ../common/%.s
	ca65 $(INCLUDES) --cpu 65c02  $<

%.lst: ../common/%.s
	ca65 $(INCLUDES) --cpu 65c02 $< -l $@

load: sbl.bin
	../../x65pyhost/do-cpureset.py -r 0
	echo "Loading bios.bin to SRAM 0x00C000"
	../../x65pyhost/do-loadbin.py bios.bin sram 0x0C000
	echo "Loading of816rom to SRAM 0x010000"
	../../x65pyhost/do-loadbin.py $(OF816ROM) sram 0x10000


# program the complete binary image into SPI-Flash as the SBL
prog_img: img.bin
	../../x65prog/x65prog -N -o 256k $<

clean:
	rm -f *.o sbl.bin *.lst img.bin ../common/*.o ../common/*.lst bios.bin *.map
