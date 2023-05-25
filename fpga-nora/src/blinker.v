/**
 * LED blinking - mainly for debug function, to indicate that the design is alive.
 * 
 * The parameter LED_OFF specifies the LED polarity - OFF state level. It can be 0 or 1,
 * the default is 1, i.e. LED is active-low.
 * 
 * The parameter TOP is the top value in a timer/counter. The counter runs at the clk frequency,
 * which is normally 48MHz. When the counter expires (reaches 0), the LED output level
 * is inverted. Therefore, the LED on and off time equals TOP * 1/48MHz seconds.
 * The complete period is twice the time.
 */
module blinker #(
    // parameters
    parameter LED_OFF = 1'b1,               // active-low LED
    parameter TOP = 32'hFFFFFF              // 0.35s on/off time => period 0.7s
) (
    // Global Inputs
    input       clk,                        // 48MHz
    input       resetn,                     // reset is active-low, synchronous with clk
    // Blinking Enable (1), otherwise (0) the LED is off.
    input       blink_en,
    // LED output signal
    output reg  led_o
);
    // Counter/timer 32-bit, runs at clk frequencey when blinking is enabled.
    // Counts from TOP down to 0.
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
