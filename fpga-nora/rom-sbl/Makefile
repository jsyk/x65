# the rom.bin is found in x16-rom/build/x16/
SBLBIN=rom.bin

prog_sbl: $(SBLBIN)
	../../x65prog/x65prog -N -o 256k $<
