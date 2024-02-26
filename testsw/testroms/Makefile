
all: blink.bin microhello.bin banktest.bin spitest.bin run816.bin getregs.bin getregs.lst

blink.bin: blink.o
blink.o: blink.s

microhello.bin: microhello.o
microhello.o: microhello.s

banktest.bin: banktest.o
banktest.o: banktest.s

spitest.bin: spitest.o
spitest.o: spitest.s

run816.bin: run816.o

getregs.bin: getregs.o
getregs.lst: getregs.s

%.bin: %.o
	ld65 -C romboot.ld $< -o $@

%.o: %.s
	ca65 --cpu 65c02  $<

%.lst: %.s
	ca65 --cpu 65c02 $< -l $@
