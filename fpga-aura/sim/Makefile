
IKAOPMSRC = ../../IKAOPM/HDL/IKAOPM.v ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_acc.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_eg.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_lfo.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_noise.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_op.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_pg.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_primitives.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_reg.v \
		../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timer.v  ../../IKAOPM/HDL/IKAOPM_modules/IKAOPM_timinggen.v

SYNSRC = $(IKAOPMSRC) ../src/aura.v ../../fpga-nora/src/i2s_encoder.v ../../fpga-nora/src/resetgen.v


# generic rules

%.vcd: %.vp
	vvp $^ -lxt2

%.vp: ../src/%.v
	iverilog -g2012 -D SIMULATION -o $@ $^


tb_aura.vp: $(SYNSRC) ../src/tb_aura.v


show_aura: tb_aura.vcd
	gtkwave $^


clean:
	rm -f *.vcd *.vp
