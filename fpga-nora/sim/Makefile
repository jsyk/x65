
# generic rules

%.vcd: %.vp
	vvp $^ -lxt2

%.vp: ../src/%.v
	iverilog -o $@ $^


# tb_phaser.vcd: tb_phaser.vp

tb_phaser.vp: ../src/tb_phaser.v ../src/phaser.v

tb_spi_slave.vp: ../src/tb_spi_slave.v ../src/spi_slave.v

tb_ps2port.vp: ../src/tb_ps2port.v ../src/ps2_port.v

show_phaser: tb_phaser.vcd
	gtkwave $^

show_spi_slave: tb_spi_slave.vcd
	gtkwave $^

show_ps2port: tb_ps2port.vcd
	gtkwave $^

clean:
	rm -f *.vcd *.vp
