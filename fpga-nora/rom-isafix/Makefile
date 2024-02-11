
all: isafix.mem

isafix.bin: isafix.o
isafix.o: isafix.s


%.mem: %.bin
	hexdump -v -e '8/1 "%02X " "\n"' $< > $@

%.bin: %.o isafix.ld
	ld65 -C isafix.ld $< -o $@

%.o: %.s
	ca65 --cpu 65c02  $< -l $@.lst

clean:
	rm -f isafix.bin isafix.mem isafix.o

load: isafix.bin
	../../x65pyhost/do-loadbin.py isafix.bin sram 0x07e000
