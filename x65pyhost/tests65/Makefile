

microhello.bin: microhello.o
# ld65 -C romboot.ld microhello.o -o microhello.bin

microhello.o: microhello.s
# ca65 --cpu 65c02  microhello.s


%.bin: %.o
	ld65 -C romboot.ld $< -o $@

%.o: %.s
	ca65 --cpu 65c02  $<
