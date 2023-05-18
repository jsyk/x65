module pulser 
(
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    //
    output reg      ck1us
);
    // IMPLEMENTATION

    reg [6:0]   ck1us_counter;

    // generate 1us pulses for PS2 port
    always @(posedge clk6x) 
    begin
        // reset pulse
        ck1us <= 0;
        if (!resetn)
        begin
            // reset the counter
            ck1us_counter <= 7'd47;
        end else begin
            // is expired?
            if (ck1us_counter == 0)
            begin
                // expired -> generate ck1us pulse
                ck1us <= 1;
                // reset the counter
                ck1us_counter <= 7'd47;
            end else begin
                // counting
                ck1us_counter <= ck1us_counter - 7'd1;
            end
        end
    end

endmodule
