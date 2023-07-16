
SYNSRC = ../src/phaser.v ../src/blinker.v ../src/resetgen.v ../src/fifo.v \
	../src/pulser.v ../src/simple_via.v ../src/spi_slave.v ../src/i2c_slave.v \
	../src/ps2_port.v ../src/ps2_kbd_host.v \
	../src/icd_controller.v ../src/bus_controller.v \
	../src/smc.v ../src/ps2_scancode_to_keycode.v ../src/spi_master.v \
	../src/bootrom.v \
	../src/nora.v


# generic rules

%.vcd: %.vp
	vvp $^ -lxt2

%.vp: ../src/%.v
	iverilog -D SIMULATION -o $@ $^


# tb_phaser.vcd: tb_phaser.vp

tb_phaser.vp: ../src/tb_phaser.v ../src/phaser.v

tb_spi_slave.vp: ../src/tb_spi_slave.v ../src/spi_slave.v

tb_spi_master.vp: ../src/tb_spi_master.v ../src/spi_master.v

tb_ps2port.vp: ../src/tb_ps2port.v ../src/ps2_port.v

tb_i2c.vp: ../src/tb_i2c.v ../src/i2c_slave.v

tb_fifo.vp: ../src/tb_fifo.v ../src/fifo.v

tb_nora.vp: $(SYNSRC) ../src/tb_nora.v

tb_ps2kbdhost.vp: ../src/tb_ps2kbdhost.v ../src/ps2_kbd_host.v ../src/pulser.v ../src/ps2_port.v ../src/fifo.v

show_phaser: tb_phaser.vcd
	gtkwave $^

show_spi_slave: tb_spi_slave.vcd
	gtkwave $^

show_ps2port: tb_ps2port.vcd
	gtkwave $^

show_i2c: tb_i2c.vcd
	gtkwave $^

show_fifo: tb_fifo.vcd
	gtkwave $^

show_nora: tb_nora.vcd
	gtkwave $^

show_ps2kbdhost: tb_ps2kbdhost.vcd
	gtkwave $^

show_spi_master: tb_spi_master.vcd
	gtkwave $^

clean:
	rm -f *.vcd *.vp
