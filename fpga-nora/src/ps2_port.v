/**
 * PS2 Port for Keyboard or Mouse
 */
module ps2_port
(
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    input           ck1us,      // 1 usec-spaced pulses, 1T long
    // PS2 port signals
    input           PS2_CLK,        // CLK line state
    input           PS2_DATA,       // DATA line state
    output reg      PS2_CLKDR0,     // 1=>drive zero on CLK, 0=>HiZ
    output reg      PS2_DATADR0,    // 1=>drive zero on DATA, 0=>HiZ
    // 
    output reg [7:0] code_rx_o,       // received scan-code
    output reg       code_rx_v_o       // scan-code valid
);
// IMPLEMENTATION
    // input synchronization registers for PS2_CLK and PS2_DATA
    reg     ps2_clk_d1;
    reg     ps2_clk_d2;
    reg     ps2_clk_d3;
    reg     ps2_data_d1;
    reg     ps2_data_d2;
    wire    clk_falling;

    always @(posedge clk6x) 
    begin
        ps2_clk_d1 <= PS2_CLK;
        ps2_clk_d2 <= ps2_clk_d1;
        ps2_clk_d3 <= ps2_clk_d2;
        ps2_data_d1 <= PS2_DATA;
        ps2_data_d2 <= ps2_data_d1;
    end

    assign clk_falling = !ps2_clk_d2 && ps2_clk_d3;


    parameter SAMPLING_DELAY = 15;
    parameter INHIBIT_TIMEOUT = 200;

    parameter R_IDLE = 4'h0;
    parameter R_START = 4'h1;
    parameter R_WF_DATA = 4'h2;
    parameter R_DATABIT = 4'h3;
    parameter R_CHECKPAR = 4'h4;
    parameter R_WF_STOP = 4'h5;
    parameter R_STOP = 4'h6;
    parameter R_WAIT_IDLE = 4'h7;
    parameter R_GENERATE_INHIBIT = 4'h8;

    reg [3:0]   state;                  // overall FSM state
    reg [4:0]   datbitnum;              // receiving data bit number
    reg [8:0]   rdata;                  // received data, parity at MSB
    reg         rparity;                // parity of the rdata

    reg [7:0]   stimer_cnt;             // sampling timer: counter at 1us rate
    reg         stimer_run;             // sampling timer: enable/run bit


    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            code_rx_o <= 8'h00;
            code_rx_v_o <= 0;
            state <= R_WAIT_IDLE;
            stimer_cnt <= 8'h00;
            stimer_run <= 0;
            PS2_CLKDR0 <= 1'b0;
            PS2_DATADR0 <= 0;
            datbitnum  <= 3'b000;
            rparity <= 0;
        end else begin
            // clear one-off signals
            code_rx_v_o <= 0;

            // handle the timer
            if (stimer_run && ck1us)
            begin
                stimer_cnt <= stimer_cnt - 1;
                if (stimer_cnt - 1 == 0)
                begin
                    // reaching zero -> expired -> stop
                    stimer_run <= 0;
                end
            end

            // handle the state machine
            case (state)
                R_IDLE:
                begin
                    if (clk_falling)
                    begin
                        state <= R_START;
                        // start the sampling timer to delay the sample point after the falling edge
                        stimer_cnt <= SAMPLING_DELAY;
                        stimer_run <= 1;
                    end
                end
                
                R_START:        // receiving the START bit
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => sample the data line now
                        if (!ps2_data_d2)
                        begin
                            // correct START=0 bit received
                            state <= R_WF_DATA;
                            // rdata <= 0;
                            rparity <= 0;
                            datbitnum <= 3'b000;
                        end else begin
                            // wrong start bit (1) received!
                            state <= R_WAIT_IDLE;
                        end
                    end
                end

                R_WF_DATA:      // waiting for a falling CLK edge, then receive a data bit
                begin
                    if (clk_falling)
                    begin
                        state <= R_DATABIT;
                        // start the sampling timer to delay the sample point after the falling edge
                        stimer_cnt <= SAMPLING_DELAY;
                        stimer_run <= 1;
                    end
                end

                R_DATABIT:        // receiving a DATA bit
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => sample the data line now;
                        // put received bit at the MSB, shift right.
                        rdata <= { ps2_data_d2, rdata[8:1] };
                        // update running parity
                        rparity <= rparity ^ ps2_data_d2;
                        // enough bits? we want 9, including the parity bit
                        if (datbitnum == 4'd8)
                        begin
                            // 9-th bit (parity) has been received.
                            state <= R_CHECKPAR;
                        end else begin
                            // continue with the next bit
                            datbitnum <= datbitnum + 1;
                            state <= R_WF_DATA;
                        end
                    end
                end

                R_CHECKPAR:     // check recevied data vs parity bit
                begin
                    if (rparity)
                    begin
                        // odd parity correct
                        state <= R_WF_STOP;
                    end else begin
                        // wrong parity!!
                        state <= R_GENERATE_INHIBIT;
                        stimer_cnt <= INHIBIT_TIMEOUT;
                        stimer_run <= 1;
                    end
                end

                R_WF_STOP:      // wait for the falling clock of the STOP bit
                begin
                    if (clk_falling)
                    begin
                        state <= R_STOP;
                        // start the sampling timer to delay the sample point after the falling edge
                        stimer_cnt <= SAMPLING_DELAY;
                        stimer_run <= 1;
                    end
                end

                R_STOP:         // receiving the STOP bit (should be 1)
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => sample the data line now;
                        if (ps2_data_d2)
                        begin
                            // correct STOP bit received! Pass the data on!
                            code_rx_o <= rdata[7:0];
                            code_rx_v_o <= 1;
                        end else begin
                            // wrong STOP bit! -> throw the data away
                        end
                        state <= R_WAIT_IDLE;
                    end
                end

                R_WAIT_IDLE:    // waiting for line IDLE state after a STOP bit
                begin
                    if (ps2_clk_d3 && ps2_clk_d2 && ps2_data_d2 && ps2_data_d1)
                    begin
                        state <= R_IDLE;
                    end
                end

                R_GENERATE_INHIBIT:     // pull CLK low for >100us to signalize parity error
                begin
                    PS2_CLKDR0 <= 1;
                    if (!stimer_run)
                    begin
                        // sampling timer expired => end of inhibit condition
                        PS2_CLKDR0 <= 0;
                        // wait for idle and start again.
                        state <= R_WAIT_IDLE;
                    end
                end

                default:
                begin
                    state <= R_WAIT_IDLE;
                end
            endcase
        end
    end

endmodule
