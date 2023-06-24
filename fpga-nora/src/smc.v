/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * System Management Controller defined by CX16.
 * It primarily responds on I2C bus as the slave device at address 0x42.
 * It provides these registers over I2C:
 *      0x07		Read from keyboard buffer
 *      0x18		Read ps2 (keyboard) status
 *      0x19	    00..FF	Send ps2 command
 *      0x21		Read from mouse buffer     <- TBD, not implemented yet here!!
 * 
 * Keyboard initialization sequence:
 *      After power-up, a keyboard runs a built-in self-test routine (BAT) and flashes all three LED.
 *      Then the keyboard sends the code 0xAA = test sucessful (or 0xFC = error).
 *      After that, a PS2 keyboard is in normal mode: it acceps commands, and sends scan-codes
 *      as keys are pressed.
 *      However, if this is a keyboard with a dual USB and PS2 interface, then more is needed.
 *      After a power up and a sucessful BAT, they keyboard oscillates between USB mode and PS2 mode.
 *      Always when it enters the PS2 mode for a while, it sends the 0xAA code and waits for any
 *      PS2 command from the host. If none is received within a short time, it goes to USB mode
 *      to try the USB protocol. But if a PS2 command is received, the keyboard knows that the host
 *      is PS2 and will stay in the PS2 mode indefinitely.
 *      This hardware will recognize the 0xAA code and respond with a two-byte command: 0xED 0x00.
 *      The command will just disable all LEDs.
 *      This was tested with AMEITEC AM-K2001W.
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
    output          PS2K_DATADR,
    // PS2 Mouse port
    input           PS2M_CLK,
    input           PS2M_DATA,
    output          PS2M_CLKDR0,
    output          PS2M_DATADR0
);
    // IMPLEMENTATION ----------------------------------------------------------------------------

    // I2C bus interface signals ---------------------------------------------------------
    wire        devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    wire        rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    wire [7:0]  rxbyte;          // the received byte for device
    wire        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    reg  [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    wire        txbyte_deq;       // the txbyte has been consumed (1T)

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


    // Pulser --------------------------------------------------------------------------
    // generate 1us pulses for PS2 port
    wire         ck1us;
    
    pulser pulser_1us
    (
        .clk6x (clk6x),       // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us)
    );

    // KEYBOARD HOST ------------------------------------------------------------------
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

    wire            kbd_bat_ok;
    reg             kbd_init_insert_second;     // kbd init second step flag

    // Keyboard
    ps2_kbd_host kbd (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us),      // 1us pulses
        // Generic host interface
        // Read from keyboard buffer (from RX FIFO)
        .kbd_rdata_o (kbd_rdata),      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
        .kbd_rvalid_o (kbd_rvalid),     // RX FIFO byte is valid? (= FIFO not empty?)
        .kbd_rdeq_i (kbd_rdeq),       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
        // Keyboard reply status register, values:
        //      0x00 => idle (no transmission started)
        //      0x01 => transmission pending
        //      0xFA => ACK received
        //      0xFE => ERR received
        .kbd_stat_o (kbd_stat),
        .kbd_bat_ok_o (kbd_bat_ok),      // received the BAT OK code (0xAA) from the keyboard
        // Write to keyboard:
        .kbd_wcmddata_i (kbd_wcmddata),           // byte for TX FIFO to send into PS2 keyboard
        .kbd_enq_cmd1_i (kbd_enq_cmd1),           // enqueu 1Byte command
        .kbd_enq_cmd2_i (kbd_enq_cmd2),           // enqueu 2Byte command+data
        // PS2 Keyboard port - FPGA pins
        .PS2K_CLK (PS2K_CLK),
        .PS2K_DATA (PS2K_DATA),
        .PS2K_CLKDR (PS2K_CLKDR),         // 1=drive PS2K_CLK to zero (L)
        .PS2K_DATADR (PS2K_DATADR)         // 1=drive PS2K_DATA to zero (L)
    );


    // MOUSE HOST ------------------------------------------------------------------
    // Read from mouse buffer (from RX FIFO)
    wire [7:0]      ms_rdata;      // RX FIFO byte from PS2 mouse, or 0x00 in case !ms_rvalid
    wire            ms_rvalid;     // RX FIFO byte is valid? (= FIFO not empty?)
    wire [4:0]      ms_rcount;       // RX FIFO count of bytes currently
    reg             ms_rdeq;       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
    // Mouse reply status register, values:
    //      0x00 => idle (no transmission started)
    //      0x01 => transmission pending
    //      0xFA => ACK received
    //      0xFE => ERR received
    wire [7:0]      ms_stat;
    // Write to mouse:
    reg [7:0]       ms_wcmddata;           // byte for TX FIFO to send into PS2 mouse
    reg             ms_enq_cmd1;           // enqueu 1Byte command
    reg             ms_enq_cmd2;           // enqueu 2Byte command+data
    wire            ms_bat_ok;


    localparam MS_BAT_WAIT = 4'h0;          // waiting for BAT from the mouse
    localparam MS_ID_WAIT = 4'h1;           // waiting for mouse ID (0x00) to be received
    localparam MS_START_RESET = 4'h2;       // sending the reset command
    localparam MS_RESET_ACK_WAIT = 4'h3;     // waiting for reset ACK
    localparam MS_SAMPLERATECMD_ACK_WAIT = 4'h4;
    localparam MS_SAMPLERATEDATA_ACK_WAIT = 4'h5;
    localparam MS_ENABLE_ACK_WAIT = 4'h6;
    localparam MS_READY = 4'h7;


    reg [3:0]       ms_init_state;

    // Mouse. reuse of kbd_host
    ps2_kbd_host #(.RXBUF_DEPTH_BITS (4)) mouse
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us),      // 1us pulses
        // Generic host interface
        // Read from keyboard buffer (from RX FIFO)
        .kbd_rdata_o (ms_rdata),      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
        .kbd_rvalid_o (ms_rvalid),     // RX FIFO byte is valid? (= FIFO not empty?)
        .kbd_rcount_o (ms_rcount),      // RX FIFO count
        .kbd_rdeq_i (ms_rdeq),       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
        // Keyboard reply status register -- not used for the mouse
        .kbd_stat_o (ms_stat),
        .kbd_bat_ok_o (ms_bat_ok),      // received the BAT OK code (0xAA) from the keyboard
        // Write to keyboard:
        .kbd_wcmddata_i (ms_wcmddata),           // byte for TX FIFO to send into PS2 keyboard
        .kbd_enq_cmd1_i (ms_enq_cmd1),           // enqueu 1Byte command
        .kbd_enq_cmd2_i (ms_enq_cmd2),           // enqueu 2Byte command+data
        // PS2 Keyboard port - FPGA pins
        .PS2K_CLK (PS2M_CLK),
        .PS2K_DATA (PS2M_DATA),
        .PS2K_CLKDR (PS2M_CLKDR0),         // 1=drive PS2K_CLK to zero (L)
        .PS2K_DATADR (PS2M_DATADR0)         // 1=drive PS2K_DATA to zero (L)
    );


    // SMC -----------------------------------------------------------------------
    // SMC / I2C registers
    localparam SMCREG_READ_KBD_BUF = 8'h07;
    localparam SMCREG_READ_PS2_KBD_STAT = 8'h18;
    localparam SMCREG_SEND_PS2_KBD_CMD = 8'h19;          // Send 1B command
    localparam SMCREG_SEND_PS2_KBD_2BCMD = 8'h1A;        // Send two-byte command
    localparam SMCREG_READ_MOUSE_BUF = 8'h21;           // Read from PS2 mouse buffer

    localparam [7:0] PS2_CMD_BAT_OK = 8'hAA;
    localparam [7:0] PS2_CMD_STAT_ACK = 8'hFA;
    localparam [7:0] PS2_CMD_ENABLE = 8'hF4;

    // SMC
    reg [7:0]   smc_regnum;         // I2C SMC register address; TBD move up the hierarchy
    reg  [1:0]  byteidx;            // I2C SMC command/data stream - position index
    reg         smc_msbuf_squashing;        // read from mouse buffer must be squashed entirely, because the first byte from mouse was wrong!
    reg         smc_msbuf_skipping;

    // Main process
    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            // KBD
            kbd_rdeq <= 0;
            kbd_wcmddata <= 8'h00;           // byte for TX FIFO to send into PS2 keyboard
            kbd_enq_cmd1 <= 0;           // enqueu 1Byte command
            kbd_enq_cmd2 <= 0;
            // SMC
            txbyte <= 8'hFF;
            byteidx <= 2'b00;
            smc_regnum <= 8'h00;
            // KBD init fsm
            kbd_init_insert_second <= 0;
            // Mouse
            ms_rdeq <= 0;
            ms_wcmddata <= 8'h00;           // byte for TX FIFO to send into PS2 keyboard
            ms_enq_cmd1 <= 0;           // enqueu 1Byte command
            ms_enq_cmd2 <= 0;
            ms_init_state <= MS_BAT_WAIT;
            smc_msbuf_squashing <= 0;
            smc_msbuf_skipping <= 0;

        end else begin
            // clear one-off signals
            kbd_rdeq <= 0;
            kbd_enq_cmd1 <= 0;           // enqueu 1Byte command
            kbd_enq_cmd2 <= 0;
            ms_rdeq <= 0;
            ms_enq_cmd1 <= 0;           // enqueu 1Byte command
            ms_enq_cmd2 <= 0;


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

                if (rw_bit)         // I2C Read? (so we shall send - tx)
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

                        SMCREG_READ_MOUSE_BUF:
                        begin
                            // txbyte <= ms_rdata;
                            // verify the first byte from mouse buffer
                            if (byteidx == 2'd0)
                            begin
                                // first byte from the buffer -> check!
                                if (ms_rcount < 5'd3)
                                begin
                                    // not enough bytes in the RX FIFO -> send zero, don't touch the FIFO
                                    txbyte <= 8'h00;
                                    smc_msbuf_skipping <= 1;
                                    smc_msbuf_squashing <= 0;
                                end else begin
                                    // bytes enough; 
                                    smc_msbuf_skipping <= 0;
                                    // check if the first is correct according to the mouse protocol
                                    if ((ms_rdata & 8'hC8) == 8'h08)
                                    begin
                                        // correct first byte from mouse -> pass on
                                        txbyte <= ms_rdata;
                                        smc_msbuf_squashing <= 0;
                                    end else begin
                                        // wrong first byte from the mouse -> squash it!
                                        txbyte <= 8'h00;
                                        smc_msbuf_squashing <= 1;
                                    end
                                end
                            end else begin
                                // not the first byte
                                // we assume the host accesses past the first data byte on I2C just
                                // if the byte was ok (non-zero)

                                // if (!smc_msbuf_squashing)
                                // begin
                                    // not squashing, all ok:
                                    // return normal data from the mouse buffer
                                    txbyte <= ms_rdata;
                                    smc_msbuf_skipping <= 0;
                                    smc_msbuf_squashing <= 0;
                                // end else begin
                                    // returning 0 till end of this i2c transaction
                                    // txbyte <= 8'h00;
                                // end

                            end
                        end

                        default:
                        begin
                            // none
                        end
                    endcase

                    // reading from the mouse buffer?
                    // if ((smc_regnum == SMCREG_READ_MOUSE_BUF))
                    // begin
                    //     // verify the first byte from mouse buffer
                    //     if ((byteidx == 2'd1) && ((txbyte & 8'hC8) != 8'h08))
                    //     begin
                    //         // the first data byte from mouse is NOT valid => squash it
                    //         txbyte <= 8'h00;
                    //     end
                    // end

                    if (txbyte_deq)
                    begin
                        // dequed from keyboard buffer?
                        if ((smc_regnum == SMCREG_READ_KBD_BUF) && (txbyte != 8'h00))
                        begin
                            kbd_rdeq <= 1;
                        end
                        // dequed from mouse buffer?
                        if ((smc_regnum == SMCREG_READ_MOUSE_BUF))
                        begin
                            // if ((byteidx == 2'd1) || !smc_msbuf_squashing)
                            // begin
                                if (!smc_msbuf_skipping)
                                begin
                                    ms_rdeq <= 1;
                                end
                            // end
                        end
                        // next byte to host
                        byteidx <= byteidx + 2'd1;
                    end
                end
            end else begin
                // I2C device not selected -> reset variables
                byteidx <= 2'b00;
                smc_msbuf_squashing <= 0;
                smc_msbuf_skipping <= 0;
            end

            // keyboard initialization:
            // received the keyboard Succesful BAT code 0xAA ?
            // if ((kbd_rdata == 8'hAA) && (kbd_rvalid))
            if (kbd_bat_ok)
            begin
                // yes; remove 0xAA from the queue
                // kbd_rdeq <= 1;
                // send back the 0xED 0xXX -> Turn On/Off the LEDs
                kbd_wcmddata <= 8'hED;
                kbd_enq_cmd2 <= 1;
                // flag the next step
                kbd_init_insert_second <= 1;
            end

            // is this the second init step?
            if (kbd_init_insert_second)
            begin
                // yes, send the 0x02 - second part of the 0xED command:
                // kbd_wcmddata <= 8'h02;            /// 0x02 => turn-on the NumLock LED
                kbd_wcmddata <= 8'h00;              // 0x00 => turn off all LED
                kbd_enq_cmd2 <= 1;
                // init done.
                kbd_init_insert_second <= 0;
            end

            case (ms_init_state)
                MS_BAT_WAIT:        // = 4'h0;          // waiting for BAT from the mouse
                    begin
                        // did mouse send the BAT OK 0xAA ?
                        if ((ms_rdata == PS2_CMD_BAT_OK) && (ms_rvalid))
                        begin
                            // yes! remove it and continue to expect the MOUSE ID code
                            ms_rdeq <= 1;
                            ms_init_state <= MS_ID_WAIT;
                        end
                        // TBD else check watchdog!
                    end
                
                MS_ID_WAIT:         // = 4'h1;           // waiting for mouse ID (0x00) to be received
                    begin
                        // did mouse send the MOUSE ID 0x00 ?
                        if ((ms_rdata == 8'h00) && (ms_rvalid))
                        begin
                            // yes! remove it and send the SAMPLERATE COMMAND
                            ms_rdeq <= 1;
                            ms_init_state <= MS_SAMPLERATECMD_ACK_WAIT;
                            // SAMPLERATE CMD
                            ms_wcmddata <= 8'hF3;       // SET SAMPLE RATE COMMAND
                            ms_enq_cmd1 <= 1;
                        end
                        // TBD else check watchdog!
                        
                    end

                MS_START_RESET:     // = 4'h2;       // sending the reset command
                    begin
                        
                    end

                MS_RESET_ACK_WAIT:      // = 4'h3;     // waiting for reset ACK
                    begin
                        
                    end
                    
                MS_SAMPLERATECMD_ACK_WAIT:      // = 4'h4;
                    begin
                        // did mouse send the ack for our command?
                        if ((ms_rdata == PS2_CMD_STAT_ACK) && (ms_rvalid))
                        begin
                            // yes! remove it and send the SAMPLERATE COMMAND'S DATA
                            ms_rdeq <= 1;
                            ms_init_state <= MS_SAMPLERATEDATA_ACK_WAIT;
                            // SAMPLERATE DATA
                            ms_wcmddata <= 8'd60;       // SET SAMPLE RATE DATA
                            ms_enq_cmd1 <= 1;
                        end
                        // TBD else check watchdog!

                    end

                MS_SAMPLERATEDATA_ACK_WAIT:     // = 4'h5;
                    begin
                        // did mouse send the ack for our data?
                        if ((ms_rdata == PS2_CMD_STAT_ACK) && (ms_rvalid))
                        begin
                            // yes! remove it and send the ENABLE command
                            ms_rdeq <= 1;
                            ms_init_state <= MS_ENABLE_ACK_WAIT;
                            // SAMPLERATE DATA
                            ms_wcmddata <= PS2_CMD_ENABLE;
                            ms_enq_cmd1 <= 1;
                        end
                        // TBD else check watchdog!

                    end
                
                MS_ENABLE_ACK_WAIT:         // = 4'h6;
                    begin
                        // did mouse send the ack for our enable command?
                        if ((ms_rdata == PS2_CMD_STAT_ACK) && (ms_rvalid))
                        begin
                            // yes! remove it and be done
                            ms_rdeq <= 1;
                            ms_init_state <= MS_READY;
                        end
                        // TBD else check watchdog!

                    end
                
                MS_READY:               // = 4'h7;
                    begin
                        
                    end                
            endcase
        end
        
    end



endmodule
