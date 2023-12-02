/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * Filter for a button input
 */
module filter #(
    parameter WIDTH = 17
)
(
    // Global signals
    input           clk,        // 48MHz
    input           resetn,     // sync reset
    // io
    input           tick_en,
    input           in,
    output reg      out
);
    // IMPLEMENTATION

    reg                 in_r;
    reg [WIDTH-1:0]     counter;

    always @(posedge clk) 
    begin
        // decouple the input by a register
        in_r <= in;

        if (!resetn)
        begin
            // reset
            counter <= 0;
            out <= in_r;
        end else begin
            if (out != in_r)
            begin
                if (tick_en)
                begin
                    // a stable change in progress...
                    counter <= counter + 1;
                    // finished counting?
                    if (counter[WIDTH-1])
                    begin
                        // done! accept the change and reset the counter
                        out <= in_r;
                        counter <= 0;
                    end
                end
            end else begin
                // glitch in the input -> restart counting
                counter <= 0;
            end
        end
    end

endmodule
