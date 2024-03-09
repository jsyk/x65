/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        12.000 MHz
 * Requested output frequency:  240.000 MHz
 * Achieved output frequency:   240.000 MHz
 */

module pll_fast (
        input  clock_in,
        output reg clock_out,
        output locked,
        output fast_clk
        );

    reg [3:0] count_r;

    SB_PLL40_CORE #(
                .FEEDBACK_PATH("SIMPLE"),
                .DIVR(4'b0000),         // DIVR =  0
                .DIVF(7'b1001111),      // DIVF = 79
                .DIVQ(3'b010),          // DIVQ =  2
                .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
        ) uut (
                .LOCK(locked),
                .RESETB(1'b1),
                .BYPASS(1'b0),
                .REFERENCECLK(clock_in),
                .PLLOUTCORE(fast_clk)
                );

    always @(posedge fast_clk) 
    begin
        if (!locked)
        begin
            count_r <= 0;
            clock_out <= 0;
        end else begin
            // divide by 5
            if (count_r == 4)
            begin
                clock_out <= ~clock_out;
                count_r <= 0;
            end else begin
                count_r <= count_r + 1;
            end
        end
    end


endmodule
