/**
 * LED blinking - activity LED
 * 
 * The parameter LED_OFF specifies the LED polarity - OFF state level. It can be 0 or 1,
 * the default is 1, i.e. LED is active-low.
 * 
 * The parameter TOP is the top value in a timer/counter. The counter runs at the clk frequency,
 * which is normally 25MHz. When the counter expires (reaches 0), the LED output level
 * is inverted. Therefore, the LED on and off time equals TOP * 1/25MHz seconds.
 * The complete period is twice the time.
 */
module actblinker #(
    // parameters
    parameter LED_OFF = 1'b1,               // active-low LED
    parameter TOP = 24'h1F_FFFF              // 0.08s on/off time => period 0.16s
) (
    // Global Inputs
    input       clk,                        // 25MHz
    input       resetn,                     // reset is active-low, synchronous with clk
    // Blinking Enable (1), otherwise (0) the LED is off.
    input       blink_en,
    // LED output signal
    output reg  led_o
);
    // Counter/timer 23-bit, runs at clk frequencey when blinking is enabled.
    // Counts from TOP down to 0.
    reg [23:0]  counter;

    // is activity blinking running?
    reg  running;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // reset
            counter <= TOP;
            running <= 0;
            led_o <= LED_OFF;
        end else begin
            // normal operation
            if (running)
            begin
                if (counter == 23'h0)
                begin
                    // done;
                    // Shall we continue blinking?
                    if ((led_o == LED_OFF) && !blink_en)
                    begin
                        // the LED is OFF and activity stopped
                        // stop blinking
                        running <= 0;
                    end else begin
                        // continue blinking;
                        // invert led output
                        led_o <= ~led_o;
                        // restart counter
                        counter <= TOP;
                    end
                end else begin
                    // still counting
                    counter <= counter - 1;
                end
            end else begin
                // blinking inhibbited -> LED off
                led_o <= LED_OFF;
                // reset counter
                counter <= TOP;
                // check if to start
                if (blink_en)
                begin
                    // start
                    running <= 1;
                    // led ON
                    led_o <= ~LED_OFF;
                end
            end
        end
    end

endmodule
