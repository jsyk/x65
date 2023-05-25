/**
 * Host controller for PS2 keyboard.
 * It provides these registers for the SMC on I2C:
 *      0x07		Read from keyboard buffer
 *      0x18		Read ps2 (keyboard) status
 *      0x19	    00..FF	Send ps2 command
 *      0x21		Read from mouse buffer     <- TBD, not implemented yet here!!
 *
 */
module ps2_kbd_host (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    input           ck1us,      // 1us pulses
    // SMC interface
    input           devsel_i,           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    input           rw_bit_i,           // Read/nWrite bit, only valid when devsel_i=1
    input [7:0]     rxbyte_i,          // the received byte for device
    input           rxbyte_v_i,         // valid received byte (for 1T) for Write transfers
    output reg [7:0] txbyte_o,           // the next byte to transmit from device; shall be valid anytime devsel_i=1 && rw_bit_i=1
    input           txbyte_deq_i,       // the txbyte has been consumed (1T)
    // PS2 Keyboard port - FPGA pins
    input           PS2K_CLK,
    input           PS2K_DATA,
    output          PS2K_CLKDR,         // 1=drive PS2K_CLK to zero (L)
    output          PS2K_DATADR         // 1=drive PS2K_DATA to zero (L)
);
    // IMPLEMENTATION

    // SMC / I2C registers
    localparam SMCREG_READ_KBD_BUF = 8'h07;
    localparam SMCREG_READ_PS2_KBD_STAT = 8'h18;
    localparam SMCREG_SEND_PS2_KBD_CMD = 8'h19;          // Send 1B command
    localparam SMCREG_SEND_PS2_KBD_2BCMD = 8'h1A;        // Send two-byte command

    
    // PS2_CMD_STATUS : uint8_t
    localparam PS2_CMD_STAT_IDLE = 8'h00;
    localparam PS2_CMD_STAT_PENDING = 8'h01;
    localparam PS2_CMD_STAT_ACK = 8'hFA;
    localparam PS2_CMD_STAT_ERR = 8'hFE;

    reg [7:0]   smc_regnum;         // SMC register address

    // I2C bus interface signals
    // wire      devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    // wire      rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    // wire [7:0]  rxbyte;          // the received byte for device
    // wire        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    // reg  [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    // wire       txbyte_deq;       // the txbyte has been consumed (1T)
    // // output reg      tx_nacked_o         // master NACKed the last byte!
    reg  [1:0]  byteidx;

    // i2c_slave #(.SLAVE_ADDRESS(8'h84))
    // i2cslv 
    // (
    //     // Global signals
    //     .clk6x (clk6x),      // 48MHz
    //     .resetn (resetn),     // sync reset
    //     // I2C bus
    //     .I2C_SDA_i (I2C_SDA_i),
    //     .I2C_SDADR0_o (I2C_SDADR0_o),
    //     .I2C_SCL_i (I2C_SCL_i),
    //     // Device interface
    //     .devsel_o (devsel),           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    //     .rw_bit_o (rw_bit),           // Read/nWrite bit, only valid when devsel_o=1
    //     .rxbyte_o (rxbyte),          // the received byte for device
    //     .rxbyte_v_o (rxbyte_v),         // valid received byte (for 1T) for Write transfers
    //     .txbyte_i (txbyte),           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    //     .txbyte_deq_o (txbyte_deq)       // the txbyte has been consumed (1T)
    //     // .tx_nacked_o (open)         // master NACKed the last byte!
    // );


    // // generate 1us pulses for PS2 port
    // wire         ck1us;
    // pulser pulser_1us
    // (
    //     .clk6x (clk6x),       // 48MHz
    //     .resetn (resetn),     // sync reset
    //     .ck1us (ck1us)
    // );

    wire [7:0]  ps2k_rxcode;
    wire        ps2k_rxcodevalid;

    reg [7:0]   ps2k_txcode;
    reg         ps2k_txenq;
    reg         kbdtxfifo_clear;

    wire [7:0]  kbdtxfifo_rdata;          // Read port data: valid any time empty_o=0
    wire        kbdtxfifo_deq;                 // Dequeue current data from FIFO
    // Status signals
    wire        kbdfifo_txfull;                 // FIFO is full?
    wire        kbdfifo_txempty;                 // FIFO is empty?
    wire        ps2k_txcodevalid = !kbdfifo_txempty;

    wire  ps2k_busy;
    wire  ps2k_acked;
    wire  ps2k_errd;


    // PS2 Input Keyboard Port
    ps2_port ps2kbd
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us),      // 1 usec-spaced pulses, 1T long
        // PS2 port signals
        .PS2_CLK (PS2K_CLK),        // CLK line state
        .PS2_DATA (PS2K_DATA),       // DATA line state
        .PS2_CLKDR0 (PS2K_CLKDR),     // 1=>drive zero on CLK, 0=>HiZ
        .PS2_DATADR0 (PS2K_DATADR),    // 1=>drive zero on DATA, 0=>HiZ
        // 
        .code_rx_o (ps2k_rxcode),       // received scan-code
        .code_rx_v_o (ps2k_rxcodevalid),       // scan-code valid
        // Host-to-Device (TX) interface
        .cmd_tx_i (kbdtxfifo_rdata),         // command byte to send   
        .cmd_tx_v_i (ps2k_txcodevalid),         // send the command byte; recognized only when busy=0
        .cmd_tx_deq_o (kbdtxfifo_deq),
        .busy (ps2k_busy),             // ongoing RX/TX (not accepting a new command now)
        .tx_acked_o (ps2k_acked),         // our TX commend byte was ACKed by device
        .tx_errd_o (ps2k_errd)           // we got a NACK at the end of command sending
    );

    // HACK
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? nora_slv_addr[7:0] : via1_slv_datard;
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? ps2k_rxcode : via1_slv_datard;

    wire kbdfifo_full;
    wire ps2k_enq = ps2k_rxcodevalid & !kbdfifo_full;
    wire kbdfifo_empty;
    reg kbdfifo_deq;
    wire [7:0] kbdfifo_rdata;

    fifo #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (3)          // fifo keeps 2**BITDEPTH elements
    ) kbdrxfifo
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn && !kbdtxfifo_clear),     // sync reset
        // I/O Write port
        .wport_i (ps2k_rxcode),          // Write Port Data
        .wenq_i (ps2k_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (kbdfifo_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (kbdfifo_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (kbdfifo_full),                 // FIFO is full?
        .empty_o (kbdfifo_empty)                 // FIFO is empty?
    );    


    fifo #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (2)          // fifo keeps 2**BITDEPTH elements
    ) kbdtxfifo
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn  && !kbdtxfifo_clear),     // sync reset
        // I/O Write port
        .wport_i (ps2k_txcode),          // Write Port Data
        .wenq_i (ps2k_txenq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (kbdtxfifo_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (kbdtxfifo_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (kbdfifo_txfull),                 // FIFO is full?
        .empty_o (kbdfifo_txempty)                 // FIFO is empty?
    );    


    reg [7:0]  kbd_stat;

    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            txbyte_o <= 8'hFF;
            byteidx <= 2'b00;
            smc_regnum <= 8'h00;
            kbdfifo_deq <= 0;
            ps2k_txcode <= 8'h00;
            ps2k_txenq <= 0;
            // kbdtxfifo_deq <= 0;
            kbd_stat <= PS2_CMD_STAT_IDLE;
            kbdtxfifo_clear <= 0;
        end else begin
            // clear one-off signals
            kbdfifo_deq <= 0;
            ps2k_txenq <= 0;
            kbdtxfifo_clear <= 0;
            // kbdtxfifo_deq <= 0;

            if (ps2k_acked && kbdfifo_txempty)
            begin
                kbd_stat <= PS2_CMD_STAT_ACK;
            end else if (ps2k_errd)
            begin
                kbd_stat <= PS2_CMD_STAT_ERR;
                kbdtxfifo_clear <= 1;
            end else if (ps2k_txcodevalid)
            begin
                kbd_stat <= PS2_CMD_STAT_PENDING;
            end


            if (devsel_i)
            begin
                // the device is selected by master
                if (rxbyte_v_i)
                begin
                    // received a byte from master
                    if (byteidx == 2'b00)
                    begin
                        // it is the first i2c data byte after address: the register number
                        smc_regnum <= rxbyte_i;
                    end else //if ((byteidx == 2'b01) || (byteidx == 2'b10))
                    begin
                        case (smc_regnum)
                            SMCREG_SEND_PS2_KBD_CMD, SMCREG_SEND_PS2_KBD_2BCMD:
                            begin
                                if (!kbdfifo_txfull)
                                begin
                                    ps2k_txcode <= rxbyte_i;
                                    ps2k_txenq <= 1;
                                end
                            end
                        endcase
                    end
                    
                    byteidx <= byteidx + 2'd1;
                end

                if (rw_bit_i)         // I2C Read?
                begin
                    // reading from the slave -> we will transmit
                    case (smc_regnum)
                        SMCREG_READ_KBD_BUF:
                        begin
                            if (kbdfifo_empty)
                            begin
                                txbyte_o <= 8'h00;
                            end else begin
                                txbyte_o <= kbdfifo_rdata;
                            end
                        end

                        SMCREG_READ_PS2_KBD_STAT:
                        begin
                            txbyte_o <= kbd_stat;
                        end
                    endcase

                    if (txbyte_deq_i)
                    begin
                        byteidx <= byteidx + 2'd1;
                        if ((smc_regnum == SMCREG_READ_KBD_BUF) && (txbyte_o != 8'h00))
                        begin
                            kbdfifo_deq <= 1;
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

