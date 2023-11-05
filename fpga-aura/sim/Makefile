
IKAOPMSRC = ../IKAOPM/HDL/IKAOPM.v ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_acc.v  ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_eg.v \
		../IKAOPM/HDL/IKAOPM_modules/IKAOPM_lfo.v  ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_noise.v  ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_op.v \
		../IKAOPM/HDL/IKAOPM_modules/IKAOPM_pg.v  ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_primitives.v  ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_reg.v \
		../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timer.v  ../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timinggen.v

SYNSRC = $(IKAOPMSRC) ../src/aura.v ../src/i2s_encoder.v ../../fpga-nora/src/resetgen.v ../src/i2s_decoder.v


# generic rules

%.vcd: %.vp
	vvp $^ -lxt2

%.vp: ../src/%.v
	iverilog -g2012 -D SIMULATION -o $@ $^


tb_aura.vp: $(SYNSRC) ../src/tb_aura.v

IKAOPM_tb.vp: $(IKAOPMSRC) ../src/IKAOPM_tb.v

IKAOPM_48MHz_I2S_tb.vp: $(IKAOPMSRC) ../src/IKAOPM_48MHz_I2S_tb.v

show_aura: tb_aura.vcd
	gtkwave $^

show_ikaopm: IKAOPM_tb.vcd
	gtkwave $^

show_ikaopm_48Mhz: IKAOPM_48MHz_I2S_tb.vcd
	gtkwave $^

clean:
	rm -f *.vcd *.vp
