Instruction Tracing in 6502/65816 CPUs by a PC-based Debugger
==============================================================


    FPGA clk = 48MHz (1T = 20ns):
        ____      ____      ____      ____      ____      ____      ____
    ___|    |____|    |____|    |____|    |____|    |____|    |____|
        S0L       S1L       S2L       S3H       S4H       S5H
        .release_cs.        .setup_cs .                   .release_wr.
                (stopped)

    CPHI2 = 8MHz (125ns period) for the 65xx CPU:
    ___                               _____________________________
        |_____________________________|                             |__________



The CPU PHI2 clock can be also stopped at any time by this module.

