/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
module attenbtn
(
    // Global signals
    input           clk,        // 48MHz
    input           resetn,     // sync reset
    // User Button
    input           attbtn_i,       // active-low button input
    // System Control output
    output reg      nmi_req_no,     // active-low NMI request output to the CPU
    output          rst_req_o       // active-high global reset request for the FPGA+CPU
);
    // IMPLEMENTATION

    // prescaler generates ticks at roughly 1ms intervals
    reg [15:0]      prescaler_r = 0;
    reg             tick_1ms;

    always @(posedge clk) 
    begin
        tick_1ms <= 0;
        prescaler_r <= prescaler_r + 1;

        if (prescaler_r[15:8] == 8'hBB)
        begin
            prescaler_r <= 0;
            tick_1ms <= 1;
        end 
    end

    // low-pass filtered input from the button
    wire            btn_filtered;

    // input filter for the ATT button
    filter #(
        .WIDTH          (4)
    ) btnflt
    (
        // Global signals
        .clk            (clk),        // 48MHz
        .resetn         (resetn),     // sync reset
        // io
        .tick_en        (tick_1ms),
        .in             (attbtn_i),
        .out            (btn_filtered)
    );

    // detection of a long-press
    localparam LONG_PRESS_WIDTH = 10;
    reg [LONG_PRESS_WIDTH:0]   press_timer_r = 0;
    reg                 blocking_after_res = 0;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            press_timer_r <= 0;
            nmi_req_no <= 1;
            // rst_req_o <= 0;
        end else begin
            // NMI request is directly from the button
            nmi_req_no <= btn_filtered | blocking_after_res;

            if (btn_filtered == 0)          // active low
            begin
                if (tick_1ms)
                begin
                    // the button is pressed, the press-counter shall run
                    press_timer_r <= press_timer_r + 1;
                end
            end else begin
                // the button is not pressed -> reset the timer.
                press_timer_r <= 0;
                blocking_after_res <= 0;
            end

            if (rst_req_o)
            begin
                blocking_after_res <= 1;
            end
        end
    end

    // reset request based on press_timer MSB
    assign rst_req_o = press_timer_r[LONG_PRESS_WIDTH] && !blocking_after_res;

endmodule
