/**
 * LED blinking
 */
module blinker #(
    // parameters
    parameter LED_OFF = 1'b1,
    parameter TOP = 32'hFFFFFF
) (
    // Global Inputs
    input       clk,
    input       resetn,
    // 
    input       blink_en,
    //
    output reg  led_o
);
    // timer
    reg [31:0]  counter;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // reset
            counter <= TOP;
            led_o <= LED_OFF;
        end else begin
            // normal operation
            if (blink_en)
            begin
                if (counter == 32'h0)
                begin
                    // invert led output
                    led_o = ~led_o;
                    // restart counter
                    counter <= TOP;
                end else begin
                    // still counting
                    counter <= counter - 1;
                end
            end else begin
                // blinking inhibbited -> LED off
                led_o <= LED_OFF;
                // reset counter
                counter <= TOP;
            end
        end
    end

endmodule
