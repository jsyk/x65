
OF816ROM=of816-x65.bin
INCLUDES = -I../../include -I.


# All the targets for the complete build
all: sbl.bin sbl.lst isafix.lst trampoline.lst img.bin

# Complete image file is composed from the SBL and the OF816ROM as the payload
img.bin: sbl.bin rombios.bin $(OF816ROM)
	cat sbl.bin rombios.bin $(OF816ROM) >img.bin

rombios.bin : vt.o font8x8.o romstru.o
	ld65 -C rombios.ld $^ -o $@

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

load_sbl: sbl.bin
	echo "Loading sbl.bin to 0x080000 (ROMBANK 0)"
	../../x65pyhost/do-loadbin.py sbl.bin sram 0x080000
	# ./do-cpureset.py -r 0


# program the complete binary image into SPI-Flash as the SBL
prog_img: img.bin
	../../x65prog/x65prog -N -o 256k $<

clean:
	rm -f *.o sbl.bin *.lst img.bin ../common/*.o ../common/*.lst rombios.bin
