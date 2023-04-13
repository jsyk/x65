/* 
 * Phaser generates CPU and VIA phased clocks CPHI2, VPHI2
 * and supporting signals for control of the cpu and memory bus.
 *
 * clk6x - 48MHz:
 *     ____      ____      ____      ____      ____      ____      ____
 * ___|    |____|    |____|    |____|    |____|    |____|    |____|
 *      S0L       S1L       S2L       S3H       S4H       S5H
 *     release_cs          setup_cs                      release_wr
 *               (stopped)
 *
 * cphi2 - 8MHz:
 * ___                               ________________________
 *    |_____________________________|                        |__________
 *
 *
 */
module phaser (
    input   clk6x,          // system clock, 6x faster than the 65C02 clock -> NORA has 6 microcycles (@48MHz) per one CPU cycle (@8MHz)
    input   resetn,           // system reset, low-active sync.
    input   run,            // allows the CPU to run
    output reg  stopped,    // indicates that the CPU is stopped (in a safe phase)
    output reg  cphi2,      // generated 65C02 PHI2 clock
    output reg  vphi2,      // generated 65C22 PHI2 clock, which is shifted by +60deg (21ns)
    output reg  setup_cs,   // catch CPU address and setup the CSx signals
    output reg  release_wr, // release write signal now, to have a hold before the cs-release
    output reg  release_cs  // CPU access is complete, release the CS
);

    parameter S0L = 3'b000;
    parameter S1L = 3'b001;
    parameter S2L = 3'b010;
    parameter S3H = 3'b011;
    parameter S4H = 3'b100;
    parameter S5H = 3'b101;

    reg [2:0]   state_reg;

    // Phasing State Machine
    always @(posedge clk6x)
    begin
        if (!resetn) 
        begin
            state_reg <= S0L;
            cphi2 <= 1'b0;
            vphi2 <= 1'b1;
            setup_cs <= 1'b0;
            release_wr <= 1'b0;
            release_cs <= 1'b0;
            stopped <= 1'b0;
        end else begin
            // default outputs:
            setup_cs <= 1'b0;
            release_wr <= 1'b0;
            release_cs <= 1'b0;
            stopped <= 1'b0;

            case (state_reg)
                S0L:
                    begin
                        state_reg <= S1L;
                        cphi2 <= 1'b0;
                        vphi2 <= 1'b0;          // falling edge vphi2
                    end

                S1L:
                    begin
                        if (run) 
                        begin
                            state_reg <= S2L;
                            cphi2 <= 1'b0;
                            vphi2 <= 1'b0;
                            setup_cs <= 1'b1;       // catch address in the next microcycle
                        end else begin
                            stopped <= 1'b1;
                        end
                    end
                
                S2L: 
                    begin
                        state_reg <= S3H;
                        cphi2 <= 1'b1;      // rising edge cphi2
                        vphi2 <= 1'b0;
                    end
                
                S3H:
                    begin
                        state_reg <= S4H;
                        cphi2 <= 1'b1;
                        vphi2 <= 1'b1;      // rising edge vphi2
                    end

                S4H:
                    begin
                        state_reg <= S5H;
                        cphi2 <= 1'b1;
                        vphi2 <= 1'b1;
                        release_wr <= 1'b1;     // release MWR signals in the next microcycle
                    end

                S5H:
                    begin
                        state_reg <= S0L;
                        cphi2 <= 1'b0;          // falling edge cphi2
                        vphi2 <= 1'b1;
                        release_cs <= 1'b1;     // release CS signals in the next microcycle
                    end

                default:
                    begin
                        state_reg <= S0L;
                        cphi2 <= 1'b0;
                        vphi2 <= 1'b1;
                    end
            endcase
        end
    end 

endmodule
