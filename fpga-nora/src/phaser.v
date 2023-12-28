/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/* 
 * Phaser generates CPU phased clock CPHI2
 * and supporting signals for control of the cpu and memory bus.
 *
 * clk - 48MHz (1T = 20ns):
 *     ____      ____      ____      ____      ____      ____      ____
 * ___|    |____|    |____|    |____|    |____|    |____|    |____|
 *      S0L       S1L       S2L       S3H       S4H       S5H
 *    .release_cs.        .setup_cs .                   .release_wr.      <=  CURRENT
 *    .release_cs.        .latch_ad .setup_cs .         .release_wr.      <= TBD !!
 *               (stopped)
 *
 * cphi2 - 8MHz (125ns period) for the 65CPU:
 * ___                               _____________________________
 *    |_____________________________|                             |__________
 *
 *
 */
module phaser (
    // Global signals
    input   clk,          // system clock, 6x faster than the 65C02 clock -> NORA has 6 microcycles (@48MHz) per one CPU cycle (@8MHz)
    input   resetn,           // system reset, low-active sync.
    // RUN/STOP signal for the generated CPU clock (cphi2).
    // The CPHI2 is stopped just always in the S1L phase!
    input   run,            // allows the CPU to run (1), or stops (0) it on S1L
    output reg  stopped,    // indicates that the CPU is stopped (in the safe phase S1L)
    // cycle extension
    input [1:0] s4_ext_i,       // extend the S4H cycle by additional clk cycles
    // generated CPU clock for 65C02
    output reg  cphi2,      // generated 65C02 PHI2 clock
    // state signals for controlling the bus cycle in the FPGA. See diagram above.
    output reg  latch_ad,   // address bus shall be registered; also, in the 24-bit mode, latch the upper 8b on the data bus
    output reg  setup_cs,   // catch CPU address and setup the CSx signals
    output reg  release_wr, // release write signal by the next rising edge, to have a hold before the cs-release
    output reg  release_cs  // CPU access is complete, release the CS by the next rising edge
);
// IMPLEMENTATION
    localparam S0L = 3'b000;
    localparam S1L = 3'b001;
    localparam S2L = 3'b010;
    localparam S3H = 3'b011;
    localparam S4H = 3'b100;
    localparam S5H = 3'b101;

    reg [2:0]   state_reg;      // FSM state
    reg [1:0]   s4_ext_r;       // S4H phase extension

    // Phasing State Machine
    always @(posedge clk)
    begin
        if (!resetn) 
        begin
            state_reg <= S0L;
            cphi2 <= 1'b0;
            latch_ad <= 1'b0;
            setup_cs <= 1'b0;
            release_wr <= 1'b0;
            release_cs <= 1'b0;
            stopped <= 1'b0;
            s4_ext_r <= 2'b00;
        end else begin
            // default outputs:
            latch_ad <= 1'b0;
            setup_cs <= 1'b0;
            release_wr <= 1'b0;
            release_cs <= 1'b0;
            stopped <= 1'b0;

            case (state_reg)
                S0L:
                    begin
                        state_reg <= S1L;
                        cphi2 <= 1'b0;
                    end

                S1L:
                    begin
                        if (run) 
                        begin
                            state_reg <= S2L;
                            cphi2 <= 1'b0;
                            setup_cs <= 1'b1;       // catch address in the next microcycle
                            latch_ad <= 1'b1;       // catch address in the next microcycle
                        end else begin
                            stopped <= 1'b1;
                        end
                    end
                
                S2L: 
                    begin
                        state_reg <= S3H;
                        cphi2 <= 1'b1;      // rising edge cphi2
                    end
                
                S3H:
                    begin
                        state_reg <= S4H;
                        cphi2 <= 1'b1;
                        s4_ext_r <= s4_ext_i;       // get the extension cycle count for S4H state
                    end

                S4H:
                    begin
                        // shall we extend the S4H ?
                        if (s4_ext_r != 2'b00)
                        begin
                            // extend the S4H
                            s4_ext_r <= s4_ext_r - 1;
                            state_reg <= S4H;
                        end else begin
                            // no extension, or extension finished
                            // go to S5H
                            state_reg <= S5H;
                            cphi2 <= 1'b1;
                            release_wr <= 1'b1;     // release MWR signals in the next microcycle
                        end
                        cphi2 <= 1'b1;
                    end

                S5H:
                    begin
                        state_reg <= S0L;
                        cphi2 <= 1'b0;          // falling edge cphi2
                        release_cs <= 1'b1;     // release CS signals in the next microcycle
                    end

                default:
                    begin
                        state_reg <= S0L;
                        cphi2 <= 1'b0;
                    end
            endcase
        end
    end 

endmodule
