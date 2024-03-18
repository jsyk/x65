
all: pbl.mem

pbl.bin: pbl.o
pbl.o: pbl.s


%.mem: %.bin
	hexdump -v -e '8/1 "%02X " "\n"' $< > $@

%.bin: %.o pbl.ld
	ld65 -C pbl.ld $< -o $@

%.o: %.s
	ca65 --cpu 65c02  $<

clean:
	rm -f pbl.bin pbl.mem pbl.o
