# the rom.bin is found in x16-rom/build/x16/
# and shall be copied here.
CX16ROM=rom.bin
INCLUDES = -I../../include -I.


# All the targets for the complete build
all: sbl.bin sbl.lst isafix.lst trampoline.lst img.bin

# Complete image file is composed from the SBL and the CX16ROM as the payload
img.bin: sbl.bin $(CX16ROM)
	cat sbl.bin $(CX16ROM) >img.bin

# Secondary Boot Loader = SBL
sbl.bin: ../common/sbl.o ../common/isafix.o
	ld65 -C ../common/sbl.ld $^ -o $@


# %.bin: %.o
# 	ld65 -C romboot.ld $< -o $@

%.o: ../common/%.s
	ca65 $(INCLUDES) --cpu 65c02  $<

%.lst: ../common/%.s
	ca65 $(INCLUDES) --cpu 65c02 $< -l $@

# load_sbl: sbl.bin
# 	echo "Loading sbl.bin to 0x080000 (ROMBANK 0)"
# 	../../x65pyhost/do-loadbin.py sbl.bin sram 0x080000
# 	# ./do-cpureset.py -r 0


# program the binary into SPI-Flash as the SBL
# prog_sbl: $(CX16ROM)
# 	../../x65prog/x65prog -N -o 256k $<

# program the complete binary image into SPI-Flash as the SBL
prog_img: img.bin
	../../x65prog/x65prog -N -o 256k $<

clean:
	rm -f *.o sbl.bin *.lst img.bin
