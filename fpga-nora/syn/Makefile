PROJ = nora
# PIN_DEF = nora-mobo-rev01.pcf
PIN_DEF = nora-sbc-revA1.pcf
DEVICE = hx4k
PACKAGE = tq144

# IKAOPM is part of AURA now.
# IKAOPMSRC = ../../IKAOPM/HDL/IKAOPM.v ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_acc.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_eg.v \
# 		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_lfo.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_noise.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_op.v \
# 		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_pg.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_primitives.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_reg.v \
# 		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timer.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timinggen.v

PBL = ../bootrom-pbl/pbl.mem

SYNSRC = ../src/nora.v ../src/bus_controller.v ../src/phaser.v ../src/blinker.v \
	../src/resetgen.v ../src/pll.v ../src/spi_slave.v ../src/icd_controller.v \
	../src/simple_via.v ../src/ps2_port.v ../src/i2c_slave.v ../src/ps2_kbd_host.v \
	../src/smc.v ../src/ps2_scancode_to_keycode.v ../src/tracebuf.v ../src/filter.v ../src/attenbtn.v \
	../src/pulser.v ../src/fifo.v ../src/spi_master.v ../src/spi_host.v ../src/bootrom.v ../src/sysregs.v \
	../src/spi_master_hostctrl.v ../src/uart_rx.v ../src/uart_tx.v ../src/uart_host.v ../src/cpu_observer.v

# NORA-internal IKAOPM is disabled.
# $(IKAOPMSRC) ../src/i2s_encoder.v ../src/fm2151_ikaopm.v


all: $(PROJ).rpt $(PROJ).bin

# %.json: ../src/%.v

$(PROJ).json: $(SYNSRC) $(PBL)
	yosys -p 'synth_ice40 -top top -json $@' $(SYNSRC)

%.asc: $(PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --asc $@ --pcf $< --json $*.json

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

%_tb: %_tb.v %.v
	iverilog -o $@ $^

%_tb.vcd: %_tb
	vvp -N $< +vcd=$@

%_syn.v: %.json
	yosys -p 'read_json $^; write_verilog $@'

%_syntb: %_tb.v %_syn.v
	iverilog -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

%_syntb.vcd: %_syntb
	vvp -N $< +vcd=$@

sim: $(PROJ)_tb.vcd

postsim: $(PROJ)_syntb.vcd

prog: $(PROJ).bin
	../../x65prog/x65prog -N $<

#	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
