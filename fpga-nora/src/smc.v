/**
 * System Management Controller defined by CX16.
 * It primarily responds on I2C bus as the slave device at address 0x42.
 * It provides these registers over I2C:
 *      0x07		Read from keyboard buffer
 *      0x18		Read ps2 (keyboard) status
 *      0x19	    00..FF	Send ps2 command
 *      0x21		Read from mouse buffer     <- TBD, not implemented yet here!!
 *
 */
module smc (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // I2C bus (slave device)
    input           I2C_SDA_i,
    output          I2C_SDADR0_o,
    input           I2C_SCL_i,
    // PS2 Keyboard port
    input           PS2K_CLK,
    input           PS2K_DATA,
    output          PS2K_CLKDR,
    output          PS2K_DATADR

);
    // IMPLEMENTATION

    // I2C bus interface signals
    wire        devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    wire        rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    wire [7:0]  rxbyte;          // the received byte for device
    wire        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    wire [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    wire        txbyte_deq;       // the txbyte has been consumed (1T)
    // output reg      tx_nacked_o         // master NACKed the last byte!
    // reg  [1:0]  byteidx;

    i2c_slave #(.SLAVE_ADDRESS(8'h84))
    i2cslv 
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // I2C bus
        .I2C_SDA_i (I2C_SDA_i),
        .I2C_SDADR0_o (I2C_SDADR0_o),
        .I2C_SCL_i (I2C_SCL_i),
        // Device interface
        .devsel_o (devsel),           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
        .rw_bit_o (rw_bit),           // Read/nWrite bit, only valid when devsel_o=1
        .rxbyte_o (rxbyte),          // the received byte for device
        .rxbyte_v_o (rxbyte_v),         // valid received byte (for 1T) for Write transfers
        .txbyte_i (txbyte),           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
        .txbyte_deq_o (txbyte_deq)       // the txbyte has been consumed (1T)
        // .tx_nacked_o (open)         // master NACKed the last byte!
    );


    // generate 1us pulses for PS2 port
    wire         ck1us;
    
    pulser pulser_1us
    (
        .clk6x (clk6x),       // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us)
    );

    // Read from keyboard buffer (from RX FIFO)
    wire [7:0]      kbd_rdata;      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
    wire            kbd_rvalid;     // RX FIFO byte is valid? (= FIFO not empty?)
    reg             kbd_rdeq;       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
    // Keyboard reply status register, values:
    //      0x00 => idle (no transmission started)
    //      0x01 => transmission pending
    //      0xFA => ACK received
    //      0xFE => ERR received
    wire [7:0]      kbd_stat;
    // Write to keyboard:
    reg [7:0]       kbd_wcmddata;           // byte for TX FIFO to send into PS2 keyboard
    reg             kbd_enq_cmd1;           // enqueu 1Byte command
    reg             kbd_enq_cmd2;           // enqueu 2Byte command+data


    ps2_kbd_host kbd (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us),      // 1us pulses
        // SMC interface
        // Read from keyboard buffer (from RX FIFO)
        .kbd_rdata_o (kbd_rdata),      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
        .kbd_rvalid_o (kbd_rvalid),     // RX FIFO byte is valid? (= FIFO not empty?)
        .kbd_rdeq_i (kbd_rdeq),       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
        // Keyboard reply status register, values:
        //      0x00 => idle (no transmission started)
        //      0x01 => transmission pending
        //      0xFA => ACK received
        //      0xFE => ERR received
        .kbd_stat_o,
        // Write to keyboard:
        .kbd_wcmddata_i (kbd_wcmddata),           // byte for TX FIFO to send into PS2 keyboard
        .kbd_enq_cmd1_i (kbd_enq_cmd1),           // enqueu 1Byte command
        .kbd_enq_cmd2_i (kbd_enq_cmd2),           // enqueu 2Byte command+data

        // .devsel_i (devsel),           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
        // .rw_bit_i (rw_bit),           // Read/nWrite bit, only valid when devsel_i=1
        // .rxbyte_i (rxbyte),          // the received byte for device
        // .rxbyte_v_i (rxbyte_v),         // valid received byte (for 1T) for Write transfers
        // .txbyte_o (txbyte),           // the next byte to transmit from device; shall be valid anytime devsel_i=1 && rw_bit_i=1
        // .txbyte_deq_i (txbyte_deq),       // the txbyte has been consumed (1T)
        // PS2 Keyboard port - FPGA pins
        .PS2K_CLK (PS2K_CLK),
        .PS2K_DATA (PS2K_DATA),
        .PS2K_CLKDR (PS2K_CLKDR),         // 1=drive PS2K_CLK to zero (L)
        .PS2K_DATADR (PS2K_DATADR)         // 1=drive PS2K_DATA to zero (L)
    );

    // SMC / I2C registers
    localparam SMCREG_READ_KBD_BUF = 8'h07;
    localparam SMCREG_READ_PS2_KBD_STAT = 8'h18;
    localparam SMCREG_SEND_PS2_KBD_CMD = 8'h19;          // Send 1B command
    localparam SMCREG_SEND_PS2_KBD_2BCMD = 8'h1A;        // Send two-byte command

    // SMC
    reg [7:0]   smc_regnum;         // I2C SMC register address; TBD move up the hierarchy
    reg  [1:0]  byteidx;            // I2C SMC command/data stream - position index

    // Main process
    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            kbd_rdeq <= 0;
            kbd_wcmddata <= 8'h00;           // byte for TX FIFO to send into PS2 keyboard
            kbd_enq_cmd1 <= 0;           // enqueu 1Byte command
            kbd_enq_cmd2 <= 0;
            // txbyte_o <= 8'hFF;
            byteidx <= 2'b00;
            smc_regnum <= 8'h00;
            // rxfifo_deq <= 0;
            // txfifo_wdata <= 8'h00;
            // txfifo_enq <= 0;
            // kbd_stat <= PS2_CMD_STAT_IDLE;
            // txfifo_clear <= 0;
        end else begin
            // clear one-off signals
            // rxfifo_deq <= 0;
            // txfifo_enq <= 0;
            // txfifo_clear <= 0;
            kbd_rdeq <= 0;
            kbd_enq_cmd1 <= 0;           // enqueu 1Byte command
            kbd_enq_cmd2 <= 0;

            // if (ps2k_acked && txfifo_empty)
            // begin
            //     kbd_stat <= PS2_CMD_STAT_ACK;
            // end else if (ps2k_errd)
            // begin
            //     kbd_stat <= PS2_CMD_STAT_ERR;
            //     txfifo_clear <= 1;
            // end else if (ps2k_txcodevalid)
            // begin
            //     kbd_stat <= PS2_CMD_STAT_PENDING;
            // end


            if (devsel)
            begin
                // the device is selected by master
                if (rxbyte_v)
                begin
                    // received a byte from master
                    if (byteidx == 2'b00)
                    begin
                        // it is the first i2c data byte after address: the register number
                        smc_regnum <= rxbyte;
                    end else //if ((byteidx == 2'b01) || (byteidx == 2'b10))
                    begin
                        kbd_wcmddata <= rxbyte;
                        case (smc_regnum)
                            SMCREG_SEND_PS2_KBD_CMD:
                            begin
                                kbd_enq_cmd1 <= 1;
                            end
                            SMCREG_SEND_PS2_KBD_2BCMD:
                            begin
                                kbd_enq_cmd2 <= 1;
                            end
                        endcase
                    end
                    
                    byteidx <= byteidx + 2'd1;
                end

                if (rw_bit)         // I2C Read?
                begin
                    // reading from the slave -> we will transmit
                    case (smc_regnum)
                        SMCREG_READ_KBD_BUF:
                        begin
                            txbyte <= kbd_rdata;
                        end

                        SMCREG_READ_PS2_KBD_STAT:
                        begin
                            txbyte <= kbd_stat;
                        end
                    endcase

                    if (txbyte_deq)
                    begin
                        byteidx <= byteidx + 2'd1;
                        // dequed from keyboard buffer?
                        if ((smc_regnum == SMCREG_READ_KBD_BUF) && (txbyte != 8'h00))
                        begin
                            kbd_rdeq <= 1;
                        end
                    end
                end
            end else begin
                // I2C device not selected -> reset
                byteidx <= 2'b00;
            end
        end
        
    end



endmodule
