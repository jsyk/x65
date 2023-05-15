
all: blink.bin microhello.bin banktest.bin

blink.bin: blink.o
blink.o: blink.s

microhello.bin: microhello.o
microhello.o: microhello.s

banktest.bin: banktest.o
banktest.o: banktest.s


%.bin: %.o
	ld65 -C romboot.ld $< -o $@

%.o: %.s
	ca65 --cpu 65c02  $<
