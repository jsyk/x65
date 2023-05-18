/**
 * I2C Slave Port
 */
module i2c_slave #(
    parameter SLAVE_ADDRESS = 8'h84             // shifted
) (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // I2C bus
    input           I2C_SDA_i,
    output reg      I2C_SDADR0_o,
    input           I2C_SCL_i,
    // Device interface
    output reg      devsel_o,           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    output          rw_bit_o,           // Read/nWrite bit, only valid when devsel_o=1
    output [7:0]    rxbyte_o,          // the received byte for device
    output reg      rxbyte_v_o,         // valid received byte (for 1T) for Write transfers
    input  [7:0]    txbyte_i,           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    output reg      txbyte_deq_o,       // the txbyte has been consumed (1T)
    output reg      tx_nacked_o         // master NACKed the last byte!
);
    // IMPLEMENTATION

    // input synchronization registers for SCL and SDA
    reg     scl_d1;
    reg     scl_d2;
    reg     scl_d3;
    reg     sda_d1;
    reg     sda_d2;
    reg     sda_d3;

    always @(posedge clk6x) 
    begin
        scl_d1 <= I2C_SCL_i;
        scl_d2 <= scl_d1;
        scl_d3 <= scl_d2;
        sda_d1 <= I2C_SDA_i;
        sda_d2 <= sda_d1;
        sda_d3 <= sda_d2;
    end

    // I2C bus state detection
    wire    scl_falling = !scl_d2 && scl_d3;
    wire    scl_rising = scl_d2 && !scl_d3;
    wire    sda_falling = !sda_d2 && sda_d3;
    wire    sda_rising = sda_d2 && !sda_d3;
    wire    start_cond = sda_falling && scl_d3;
    wire    stop_cond = sda_rising && scl_d3;

    parameter SAMPLING_DELAY = 5'd30;           // 30T at 48MHz (21ns) = 630ns
    parameter OUTPUT_DELAY = 5'd10;             // 10T at 48MHz (21ns) = 210ns

    // FSM states enum:
    parameter R_IGNORE = 4'h0;            // idle - no transfer, or ignoring the ongoing transfer (address no match)
    parameter R_WR_SCL = 4'h1;          // waiting for SCL rising edge
    parameter R_DATABIT = 4'h2;
    parameter R_CHECK_ADDR = 4'h3;      // received the first byte (slave address and r/w) -> check it
    parameter T_ACK = 4'h4;             // will transmit the ACK bit; wait for the SCL to fall
    parameter T_ACKOUT = 4'h5;          // will transmit the ACK bit; SCL has falle, wait the OUTPUT_DELAY time, then drive 0
    parameter T_ACKDONE = 4'h6;         // has trasmitted the ACK bit; SCL has fallen again, wait OUTPUT_DELAY time, then deassert.
    parameter T_WF_SCL = 4'h7;
    parameter T_NEXTBIT = 4'h8;
    parameter TR_WR_SCL = 4'h9;
    parameter TR_GETACK = 4'hA;
    parameter T_WF_SCL_FIRST = 4'hB;
    parameter T_WF_SCL_FIRST_DEL = 4'hC;

    // FSM:
    reg [3:0]   state;
    reg         first_byte;
    reg         rw_bit;
    reg [7:0]   rdata;
    reg [3:0]   datbitnum;
    reg [7:0]   tdata;

    // sample delay timer:
    reg [4:0]   stimer_cnt;             // sampling timer: counter at 1us rate
    reg         stimer_run;             // sampling timer: enable/run bit

    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            // reset
            I2C_SDADR0_o <= 0;
            state <= R_IGNORE;
            first_byte <= 1;
            rw_bit <= 0;
            rdata <= 8'h00;
            tdata <= 8'h00;
            stimer_cnt <= 5'h00;
            stimer_run <= 0;
            rxbyte_v_o <= 0;
            devsel_o <= 0;
            txbyte_deq_o <= 0;
            tx_nacked_o <= 0;
        end else begin
            // clear one-off signals
            rxbyte_v_o <= 0;
            txbyte_deq_o <= 0;
            tx_nacked_o <= 0;

            // handle the timer
            if (stimer_run)
            begin
                stimer_cnt <= stimer_cnt - 5'd1;
                if (stimer_cnt - 1 == 0)
                begin
                    // reaching zero -> expired -> stop
                    stimer_run <= 0;
                end
            end

            // handle the FSM
            case (state)
                R_IGNORE:       // idle - no transfer, or ignoring the ongoing transfer (address no match)
                begin
                    I2C_SDADR0_o <= 0;
                    devsel_o <= 0;
                end

                R_WR_SCL:       // waiting for SCL rising edge
                begin
                    if (scl_rising)
                    begin
                        // delay sampling point after SCL is stable high
                        stimer_cnt <= SAMPLING_DELAY;
                        stimer_run <= 1;
                        state <= R_DATABIT;
                    end
                end

                R_DATABIT:
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => sample the data line now;
                        // (receving from MSB to LSB)
                        // put received bit at the LSB, shift left.
                        rdata <= { rdata[6:0], sda_d3 };
                        // enough bits? we want 8
                        if (datbitnum == 4'd7)
                        begin
                            // 8-th bit has been received.
                            if (first_byte)
                            begin
                                // this is the first byte after START -> check address
                                state <= R_CHECK_ADDR;
                            end else begin
                                // data byte received, now send the ACK
                                state <= T_ACK;
                                // pass the byte to device
                                rxbyte_v_o <= 1;
                            end
                        end else begin
                            // continue with the next bit
                            datbitnum <= datbitnum + 4'd1;
                            state <= R_WR_SCL;              // wait for next SCL rising
                        end
                    end
                end

                R_CHECK_ADDR:               // received the first byte (slave address and r/w) -> check it
                begin
                    if ((rdata & 8'hFE) == SLAVE_ADDRESS)
                    begin
                        // we are addressed!
                        rw_bit <= rdata[0];
                        devsel_o <= 1;
                        state <= T_ACK;
                    end else begin
                        // not for us -> ignore all until the next start condition
                        state <= R_IGNORE;
                    end
                end

                T_ACK:              // will transmit the ACK bit; wait for the SCL to fall
                begin
                    // wait for SCL falling edge
                    if (scl_falling)
                    begin
                        // delay the ACK pulse output from the falling edge a bit
                        stimer_cnt <= OUTPUT_DELAY;
                        stimer_run <= 1;
                        state <= T_ACKOUT;
                    end
                end

                T_ACKOUT:       // will transmit the ACK bit; SCL has falle, wait the OUTPUT_DELAY time, then drive 0
                begin
                    if (!stimer_run)
                    begin
                        // sampling timer expired => output the data line now;
                        I2C_SDADR0_o <= 1;
                        //
                        if (scl_falling)
                        begin
                            // another falling edge -> deactivate the ACK, with some delay
                            stimer_cnt <= OUTPUT_DELAY;
                            stimer_run <= 1;
                            state <= T_ACKDONE;
                        end
                    end
                end

                T_ACKDONE:      // has trasmitted the ACK bit; SCL has fallen again, wait OUTPUT_DELAY time, then deassert.
                begin
                    // SCL is low now;
                    if (!stimer_run)
                    begin
                        // sampling timer expired => remove output the data line now;
                        I2C_SDADR0_o <= 0;
                        // which data direction now?
                        if (rw_bit)
                        begin
                            // host reading -> we will output (transmit) the data!
                            tdata <= txbyte_i;
                            txbyte_deq_o <= 1;      // inform device that TX byte has been consumed
                            state <= T_WF_SCL;      // Transmit/Wait for the next falling SCL
                        end else begin
                            // host writing -> we accept (receive) data!
                            // wait for the rising edge on SCL which marks the first (MSB) bit of data
                            state <= R_WR_SCL;
                        end
                        // data bytes will follow...
                        first_byte <= 0;
                        datbitnum <= 0;
                    end
                end

                T_WF_SCL:           // transmitting a bit, waiting for a falling SCL
                begin
                    I2C_SDADR0_o <= ~tdata[7];
                    if (scl_falling)
                    begin
                        // the SCL has fallen -> we shall wait the output delay time, then send the next bit
                        stimer_cnt <= OUTPUT_DELAY;
                        stimer_run <= 1;
                        state <= T_NEXTBIT;
                        // continue with the next bit
                        tdata <= { tdata[6:0], 1'b0 };      // shift left
                    end
                end

                T_NEXTBIT:      // will transmit the next bit, after output delay time
                begin
                    // SCL is low now;
                    if (!stimer_run)
                    begin
                        // output delay fulfilled; release SDA
                        I2C_SDADR0_o <= 0;
                        datbitnum <= datbitnum + 4'd1;
                        // all bits done?
                        if (datbitnum == 4'd7)
                        begin
                            // yes; we shall receive an ACK now!
                            state <= TR_WR_SCL;         // wait for rising edge on SCL
                        end else begin
                            // no; next bit output, wait for next SCL falling edge
                            state <= T_WF_SCL;
                        end
                    end
                end

                TR_WR_SCL:      // receiving the ACK during transmit session, wait for SCL rising (the ACK will start)
                begin
                    // SCL is still low..
                    if (scl_rising)
                    begin
                        // sample with some delay
                        stimer_cnt <= SAMPLING_DELAY;
                        stimer_run <= 1;
                        state <= TR_GETACK;
                    end
                end

                TR_GETACK:      // receiving an ACK from master at the end of Read (Transmit) transaction
                begin
                    // SCL is high, just after a rising edge
                    if (!stimer_run)
                    begin
                        // read input and pass it to device
                        tx_nacked_o <= sda_d3;
                        if (sda_d3)
                        begin
                            // 1 = NACK from master -> stop sending, release the bus
                            state <= R_IGNORE;
                        end else begin
                            // 0 = ACK from master -> continue sending next byte
                            // wait for SCL falling before continuing with the next byte
                            state <= T_WF_SCL_FIRST;
                        end
                    end
                end

                T_WF_SCL_FIRST:     // transmit: the ACK been received, now wait for SCL falling
                begin
                    if (scl_falling)
                    begin
                        // wait the output delay time before driving the first bit
                        stimer_cnt <= OUTPUT_DELAY;
                        stimer_run <= 1;
                        state <= T_WF_SCL_FIRST_DEL;
                    end
                end

                T_WF_SCL_FIRST_DEL:     // transmit: master's ACK is finished, now wait some output delay
                begin
                    // SCL is low
                    if (!stimer_run)
                    begin
                        // get next byte from device
                        tdata <= txbyte_i;
                        txbyte_deq_o <= 1;      // inform device that the TX byte has been consumed
                        state <= T_WF_SCL;      // Transmit/Wait for the next falling SCL
                        datbitnum <= 0;
                    end
                end
                
                default:
                begin
                    state <= R_IGNORE;
                    first_byte <= 1;
                    datbitnum <= 0;
                    stimer_run <= 0;
                    devsel_o <= 0;
                    I2C_SDADR0_o <= 0;
                end
            endcase

            // the START/RESTART condition must be detected anywhere in the stream
            if (start_cond)
            begin
                state <= R_WR_SCL;
                first_byte <= 1;
                datbitnum <= 0;
                stimer_run <= 0;
                devsel_o <= 0;
                I2C_SDADR0_o <= 0;
            end

            if (stop_cond)
            begin
                state <= R_IGNORE;
                first_byte <= 1;
                datbitnum <= 0;
                stimer_run <= 0;
                devsel_o <= 0;
                I2C_SDADR0_o <= 0;
            end
        end
        
    end

    assign rxbyte_o = rdata;
    assign rw_bit_o = rw_bit;

endmodule
