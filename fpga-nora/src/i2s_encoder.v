/**
 * I2S Encoder - generates serial sound data from parallel 16-bit samples
 *
 */
module I2S_encoder #(
    parameter LRCLK_DIV = 10'd982,
    parameter BCLK_DIV = 4'd15
) (
    // Global signals
    input   clk,              // system clock 48MHz
    input   resetn,           // system reset, low-active sync.
    // Input sound samples
    input wire [15:0]       r_chan_i,
    input wire [15:0]       l_chan_i,
    // Output I2S signal
    output reg              lrclk_o,
    output reg              bclk_o,
    output reg              dacdat_o
);
    // IMPLEMENTATION

    // pre-divider for lrclk generation
    reg [9:0]  prediv_lrclk_r;

    // pre-divider for bclk generation
    reg [3:0]  prediv_bclk_r;

    // output shift register for the 16-bit data, MSB-first
    reg [15:0] shifter;

    // generate all output signals
    always @(posedge clk) 
    begin
        if (!resetn)
        begin
            prediv_lrclk_r <= 0;
            lrclk_o <= 0;
            prediv_bclk_r <= 0;
            bclk_o <= 0;
            shifter <= 0;
            dacdat_o <= 0;
        end else begin

            // BCLK generator: reached top?
            if (prediv_bclk_r == BCLK_DIV)
            begin
                // yes -> reset to 0 and falling edge
                prediv_bclk_r <= 0;
                bclk_o <= 0;
                // set output data, MSB-first
                dacdat_o <= shifter[15];
                shifter <= { shifter[14:0], 1'b0 };     // shift left, insert 0 to LSB.
            end else begin
                // no -> count
                prediv_bclk_r <= prediv_bclk_r + 1;
            end

            // BCLK in the middle?
            if (prediv_bclk_r == BCLK_DIV/2)
            begin
                // yes -> rising edge
                bclk_o <= 1;
            end


            // LRCLK: reached top?
            if (prediv_lrclk_r == LRCLK_DIV)
            begin
                // yes -> reset to 0
                prediv_lrclk_r <= 0;
                // output to 0 (falling edge on LRCLK)
                lrclk_o <= 0;
                // I2S will output LEFT channel now
                shifter <= l_chan_i;
                // reset BCLK (maybe falling edge)
                bclk_o <= 0;
                prediv_bclk_r <= 0;
            end else begin
                // no -> count
                prediv_lrclk_r <= prediv_lrclk_r + 1;
            end

            // LRCLK: in the middle?
            if (prediv_lrclk_r == LRCLK_DIV/2)
            begin
                // yes -> rising edge
                // output to 1
                lrclk_o <= 1;
                // I2S will output RIGHT channel now
                shifter <= r_chan_i;
                // reset BCLK
                bclk_o <= 0;
                prediv_bclk_r <= 0;
            end

        end
    end

endmodule
