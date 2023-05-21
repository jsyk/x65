/**
 * Autonomous reset generator
 */
module resetgen (
    input       clk,
    input       clklocked,
    input       rstreq,
    output reg  reset,
    output reg  resetn
);

    reg [3:0] counter = 4'd0;

    always @(posedge clk)
    begin
        if (!clklocked || rstreq)
        begin
            // clock not locked -> reset
            reset <= 1'b1;
            resetn <= 1'b0;
            counter <= 4'h0;
        end else begin
            // count up...
            if (counter[3] != 1'b1)
            begin
                // counting
                counter <= counter + 4'd1;
                // keep reset output
                reset <= 1'b1;
                resetn <= 1'b0;
            end else begin
                // stop counting and release the reset output
                reset <= 1'b0;
                resetn <= 1'b1;
            end
        end
    end
endmodule
