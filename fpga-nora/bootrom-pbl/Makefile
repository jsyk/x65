
all: pbl.mem trampoline.lst

pbl.bin: pbl.o
pbl.o: pbl.s


%.mem: %.bin
	hexdump -v -e '8/1 "%02X " "\n"' $< > $@

%.bin: %.o pbl.ld
	ld65 -C pbl.ld $< -o $@

%.o: %.s
	ca65 -I ../../include --cpu 65c02  $<

trampoline.lst: trampoline.s
	ca65 -I ../../include --cpu 65c02 trampoline.s --listing trampoline.lst

clean:
	rm -f pbl.bin pbl.mem pbl.o

load: pbl.bin
	../../x65pyhost/do-loadbin.py pbl.bin bootrom 0
