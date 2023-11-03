PROJ = aura
PIN_DEF = aura-vabo-rev01.pcf
DEVICE = up5k
PACKAGE = sg48

IKAOPMSRC = ../../IKAOPM/HDL/IKAOPM.v ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_acc.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_eg.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_lfo.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_noise.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_op.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_pg.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_primitives.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_reg.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timer.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timinggen.v


SYNSRC = $(IKAOPMSRC) ../src/aura.v ../../fpga-nora/src/i2s_encoder.v ../../fpga-nora/src/resetgen.v ../src/i2s_decoder.v

all: $(PROJ).rpt $(PROJ).bin

# %.json: ../src/%.v

$(PROJ).json: $(SYNSRC)
	yosys -p 'synth_ice40 -top aura -json $@' $(SYNSRC)

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
	../../x65prog/x65prog -A $<

#	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
