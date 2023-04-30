PROJ = nora
PIN_DEF = openX65-mobo-rev01.pcf
DEVICE = hx4k
PACKAGE = tq144
SYNSRC = ../src/nora.v ../src/bus_controller.v ../src/phaser.v ../src/blinker.v \
	../src/resetgen.v ../src/pll.v ../src/spi_slave.v ../src/icd_controller.v \
	../src/simple_via.v

all: $(PROJ).rpt $(PROJ).bin

# %.json: ../src/%.v

$(PROJ).json: $(SYNSRC)
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
	../../x65prog/x65prog $<

#	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
