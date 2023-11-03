/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * I2S Decoder of sound data for WM8524.
 */
module I2S_decoder 
(
    // Global signals
    input               clk,              // system clock 48MHz
    input               resetn,           // system reset, low-active sync.
    // Input I2S signal
    input               lrclk_i,
    input               bclk_i,
    input               dacdat_i,
    // Output sound samples
    output reg [15:0]       r_chan_o,           // right channel sample data
    output reg              r_strobe_o,         // right channel strobe (sample update)
    output reg [15:0]       l_chan_o,           // left channel sample data
    output reg              l_strobe_o          // left channel strobe (sample update)
);
    // synchronize the input signals lrclk_i and dacdat_i into the bclk_i clock domain:
    reg                 lrclk_r, prev_lrclk_r;
    reg                 dacdat_r;

    // input sync stage @ bclk_i
    always @(posedge bclk_i) 
    begin
        lrclk_r <= lrclk_i;
        prev_lrclk_r <= lrclk_r;
        dacdat_r <= dacdat_i;
    end

    // input serial registers @ bclk_i
    reg [15:0]          shifter_r;      // input serial shift register, clocked at bclk
    reg                 shifted_lrck_r;
    reg [4:0]           counter_r;      // input length counter

    // Shift input stream data on dacdat_r into shifter_r based on bclk_i
    // and also observe the lrclk_r which marks start of sample.
    always @(posedge bclk_i) 
    begin
        if (lrclk_r != prev_lrclk_r)
        begin
            // change of LRCLK ==> the next sub-sample begins.
            counter_r <= 5'h00;
        end else begin
            // no change of LRCLK ==> continue counting or stop?
            if (counter_r[4] == 1)
            begin
                // all bits were loaded => stop
                shifted_lrck_r <= lrclk_r;
            end else begin
                // counting and lodaing
                shifter_r <= { shifter_r[14:0], dacdat_r };
                counter_r <= counter_r + 1;
            end
        end
    end

    // re-sync the shifted_lrck_r into clk domain
    reg                 cur_sh_lrck_r;

    always @(posedge clk) 
    begin
        cur_sh_lrck_r <= shifted_lrck_r;
    end

    // remember the previous L/R flag to recognize when new data has been shifted in.
    reg                 prev_sh_lrck_r;

    // timeout watchdog
    reg [12:0]          timeout_r;


    always @(posedge clk) 
    begin
        if (!resetn)
        begin
            // reset
            r_chan_o <= 0;
            r_strobe_o <= 0;
            l_chan_o <= 0;
            l_strobe_o <= 0;
            prev_sh_lrck_r <= 0;
            timeout_r <= 0;
        end else begin
            // normal op.
            r_strobe_o <= 0;
            l_strobe_o <= 0;
            // Change in shifted L/R channel flag?
            if (prev_sh_lrck_r != cur_sh_lrck_r)
            begin
                // yes -> take the new sample into the channel
                prev_sh_lrck_r <= cur_sh_lrck_r;
                // reset timeout watchdog
                timeout_r <= 0;
                // Data for which channel?
                if (cur_sh_lrck_r)
                begin
                    // LRCK=1 == right channel:
                    r_chan_o <= shifter_r;
                    r_strobe_o <= 1;
                end else begin
                    // LRCK=0 == left channel:
                    l_chan_o <= shifter_r;
                    l_strobe_o <= 1;
                end
            end else begin
                // nothing...
                if (timeout_r[12])
                begin
                    // watchdog overflow! == no input sample in some time => reset output data to prevent stale date
                    r_chan_o <= 0;
                    l_chan_o <= 0;
                    r_strobe_o <= 1;
                    l_strobe_o <= 1;
                    timeout_r <= 0;
                end else begin
                    // watchdog runs
                    timeout_r <= timeout_r + 1;
                end
            end
        end
    end

endmodule
