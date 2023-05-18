/**
 * PS2 Port for Keyboard or Mouse
 *
 * It can receive scan-codes from a keyboard or mouse
 * and send commands.
 * TBD: 
 *  * proper handling of (parity) errors!
 *
 * Useful web resources on PS2 protocol:
 * - Interfacing a PS/2 keyboard to a microcontroller
 *   http://www.lucadavidian.com/2017/11/15/interfacing-ps2-keyboard-to-a-microcontroller/
 * - PS/2 Mouse/Keyboard Protocol
 *   http://www.burtonsys.com/ps2_chapweske.htm
 * - The PS/2 Keyboard Interface
 *   http://www-ug.eecg.toronto.edu/msl/nios_devices/datasheets/PS2%20Keyboard%20Protocol.htm
 * - The PS/2 Mouse Interface 
 *   https://isdaman.com/alsos/hardware/mouse/ps2interface.htm 
 * 
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
    // Device-to-Host (RX) interface
    output reg [7:0] code_rx_o,       // received scan-code
    output reg       code_rx_v_o,       // scan-code valid (enqueue)
    // Host-to-Device (TX) interface
    input [7:0]     cmd_tx_i,         // command byte to send   
    input           cmd_tx_v_i,         // send the command byte; recognized only when busy=0
    output reg      busy,             // ongoing RX/TX (not accepting a new command now)
    output reg      tx_acked_o,         // our TX commend byte was ACKed by device
    output reg      tx_errd_o           // we got a NACK at the end of command sending
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

    // times in microseconds
    parameter SAMPLING_DELAY = 15;
    parameter INHIBIT_TIMEOUT = 120;
    parameter REQ_SEND1_TIME = 110;
    parameter REQ_SEND2_TIME = 15;
    parameter OUTPUT_DELAY = 10;

    // enum for 'state' reg:
    parameter R_IDLE = 4'h0;
    parameter R_START = 4'h1;           // receiving the start condition
    parameter R_WF_DATA = 4'h2;         // waiting for a falling CLK edge, then receive a data bit
    parameter R_DATABIT = 4'h3;         // receiving a DATA bit
    parameter R_CHECKPAR = 4'h4;        // check recevied data vs parity bit
    parameter R_WF_STOP = 4'h5;         // wait for the falling clock of the STOP bit
    parameter R_STOP = 4'h6;            // receiving the STOP bit (should be 1)
    parameter R_WAIT_IDLE = 4'h7;       // waiting for line IDLE state after a STOP bit
    parameter R_GENERATE_INHIBIT = 4'h8;    // pull CLK low for >100us to signalize parity error
    parameter T_REQ_SEND1 = 4'h9;                // generate send request by pulling CLK low for 100us
    parameter T_REQ_SEND2 = 4'hA;                // generate send request by pulling CLK low for 100us
    parameter T_WF_DATA = 4'hB;         // waiting for clk fall from device
    parameter T_DATABIT = 4'hC;         // sending the DATA bit
    parameter T_WF_ACK = 4'hD;          // waiting for ACK 
    parameter T_RXACK = 4'hE;            // receive ACK, should be 0

    reg [3:0]   state;                  // overall FSM state
    reg [4:0]   datbitnum;              // receiving data bit number
    reg [8:0]   rdata;                  // received data, parity at MSB
    reg         parity;                // parity of the rdata
    reg [7:0]   tdata;                  // tx data

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
            parity <= 0;
            busy <= 1;
            tdata <= 8'h00;
            tx_acked_o <= 0;
            tx_errd_o <= 0;
        end else begin
            // clear one-off signals
            code_rx_v_o <= 0;
            busy <= 1;
            tx_acked_o <= 0;
            tx_errd_o <= 0;

            // handle the timer
            if (stimer_run && ck1us)
            begin
                stimer_cnt <= stimer_cnt - 8'd1;
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
                    end else if (cmd_tx_v_i)
                    begin
                        // send command byte to the device
                        tdata <= cmd_tx_i;
                        state <= T_REQ_SEND1;
                        stimer_cnt <= REQ_SEND1_TIME;
                        stimer_run <= 1;
                    end else begin
                        // really idle
                        busy <= 0;
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
                            parity <= 0;
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
                        parity <= parity ^ ps2_data_d2;
                        // enough bits? we want 9, including the parity bit
                        if (datbitnum == 4'd8)
                        begin
                            // 9-th bit (parity) has been received.
                            state <= R_CHECKPAR;
                        end else begin
                            // continue with the next bit
                            datbitnum <= datbitnum + 4'd1;
                            state <= R_WF_DATA;
                        end
                    end
                end

                R_CHECKPAR:     // check recevied data vs parity bit
                begin
                    if (parity)
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

                T_REQ_SEND1:         // generate send request by pulling CLK low for 100us
                begin
                    PS2_CLKDR0 <= 1;
                    if (!stimer_run)
                    begin
                        // timeout 1 expired -> pull DATA low
                        // pull data low.
                        PS2_DATADR0 <= 1;
                        state <= T_REQ_SEND2;
                        stimer_cnt <= REQ_SEND2_TIME;
                        stimer_run <= 1;
                    end
                end

                T_REQ_SEND2:         // continue generate send request by pulling DATA low as well
                begin
                    PS2_CLKDR0 <= 1;
                    PS2_DATADR0 <= 1;
                    if (!stimer_run)
                    begin
                        // timeout 2 expired -> release CLK, keep DATA low
                        PS2_CLKDR0 <= 0;
                        // init data bit counter, init odd parity
                        datbitnum <= 4'h0;
                        parity <= 1;
                        // wait for CLK falling from device
                        state <= T_WF_DATA;
                    end
                end

                T_WF_DATA:        // waiting for clk fall from device
                begin
                    if (clk_falling)
                    begin
                        state <= T_DATABIT;
                        // start the sampling timer to delay the output point after the falling edge
                        stimer_cnt <= OUTPUT_DELAY;
                        stimer_run <= 1;
                    end
                end

                T_DATABIT:      // sending the DATA bit
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => output the data line now;
                        // enough bits? we want 9 inc. the parity
                        if (datbitnum == 4'd8)
                        begin
                            // all data bits sent; sending the parity bit now
                            PS2_DATADR0 <= ~parity;
                            state <= T_WF_DATA;
                        end else if (datbitnum == 4'd9)
                        begin
                            // data and parity done, send the STOP
                            PS2_DATADR0 <= 0;
                            state <= T_WF_ACK;
                        end else begin
                            // continue with the next bit
                            // put tx bit from the LSB, shift right.
                            PS2_DATADR0 <= ~tdata[0];
                            tdata <= { 1'b0, tdata[7:1] };
                            // update running parity
                            parity <= parity ^ tdata[0];
                            state <= T_WF_DATA;
                        end
                        // next bit counter
                        datbitnum <= datbitnum + 4'd1;
                    end                    
                end

                T_WF_ACK:           // waiting for ACK 
                begin
                    if (clk_falling)
                    begin
                        state <= T_RXACK;
                        // start the sampling timer to delay the sampling point after the falling edge
                        stimer_cnt <= SAMPLING_DELAY;
                        stimer_run <= 1;
                    end
                end

                T_RXACK:            // receive ACK, should be 0
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => sample the data line now;
                        if (!ps2_data_d2)
                        begin
                            // correct ACK=0 bit received!
                            tx_acked_o <= 1;
                        end else begin
                            // wrong ACK=1 bit!
                            tx_errd_o <= 1;
                        end
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
