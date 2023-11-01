PROJ = aura
PIN_DEF = aura-vabo-rev01.pcf
DEVICE = up5k
PACKAGE = sg48
JT51SRC = ../../jt51/hdl/jt51_acc.v \
	../../jt51/hdl/jt51_eg.v \
	../../jt51/hdl/jt51_exp2lin.v \
	../../jt51/hdl/jt51_exprom.v \
	../../jt51/hdl/jt51_kon.v \
	../../jt51/hdl/jt51_lfo.v \
	../../jt51/hdl/jt51_lin2exp.v \
	../../jt51/hdl/jt51_mmr.v \
	../../jt51/hdl/jt51_mod.v \
	../../jt51/hdl/jt51_noise_lfsr.v \
	../../jt51/hdl/jt51_noise.v \
	../../jt51/hdl/jt51_op.v \
	../../jt51/hdl/jt51_pg.v \
	../../jt51/hdl/jt51_phinc_rom.v \
	../../jt51/hdl/jt51_phrom.v \
	../../jt51/hdl/jt51_pm.v \
	../../jt51/hdl/jt51_csr_ch.v \
	../../jt51/hdl/jt51_csr_op.v \
	../../jt51/hdl/jt51_reg.v \
	../../jt51/hdl/jt51_sh.v \
	../../jt51/hdl/jt51_timers.v \
	../../jt51/hdl/jt51.v \
	../../jt51/hdl/../ver/common/sep32.v \
	../../jt51/hdl/../ver/common/sep32_cnt.v

IKAOPMSRC = ../../IKAOPM/HDL/IKAOPM.v ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_acc.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_eg.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_lfo.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_noise.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_op.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_pg.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_primitives.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_reg.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timer.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timinggen.v


SYNSRC = $(IKAOPMSRC) ../src/aura.v ../../fpga-nora/src/i2s_encoder.v ../../fpga-nora/src/resetgen.v

# $(JT51SRC) ../src/fm2151.v

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
