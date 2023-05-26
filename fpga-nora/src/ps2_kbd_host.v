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
    // SMC interface:
    // // Read from keyboard buffer (from RX FIFO)
    // output [7:0]    kbd_rdata,      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
    // output          kbd_rvalid,     // RX FIFO byte is valid? (= FIFO not empty?)
    // input           kbd_rdeq,       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
    // // Keyboard reply status register, values:
    // //      0x00 => idle (no transmission started)
    // //      0x01 => transmission pending
    // //      0xFA => ACK received
    // //      0xFE => ERR received
    // output reg [7:0] kbd_stat,
    // // Write to keyboard:
    // input [7:0]     kbd_wcmddata,           // byte for TX FIFO to send into PS2 keyboard
    // input           kbd_enq_cmd1,           // enqueu 1Byte command
    // input           kbd_enq_cmd2,           // enqueu 2Byte command+data

    input           devsel_i,           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    input           rw_bit_i,           // Read/nWrite bit, only valid when devsel_i=1
    input [7:0]     rxbyte_i,          // the received byte for device
    input           rxbyte_v_i,         // valid received byte (for 1T) for Write transfers
    output reg [7:0] txbyte_o,           // the next byte to transmit from device; shall be valid anytime devsel_i=1 && rw_bit_i=1
    input           txbyte_deq_i,       // the txbyte has been consumed (1T)
    // PS2 Keyboard port - FPGA pins
    input           PS2K_CLK,           // pin value
    input           PS2K_DATA,          // pin value
    output          PS2K_CLKDR,         // 1=drive PS2K_CLK to zero (L)
    output          PS2K_DATADR         // 1=drive PS2K_DATA to zero (L)
);
    // IMPLEMENTATION

    // SMC / I2C registers
    localparam SMCREG_READ_KBD_BUF = 8'h07;
    localparam SMCREG_READ_PS2_KBD_STAT = 8'h18;
    localparam SMCREG_SEND_PS2_KBD_CMD = 8'h19;          // Send 1B command
    localparam SMCREG_SEND_PS2_KBD_2BCMD = 8'h1A;        // Send two-byte command

    
    // values for output reg kbd_stat: (from PS2_CMD_STATUS : uint8_t):
    localparam PS2_CMD_STAT_IDLE = 8'h00;
    localparam PS2_CMD_STAT_PENDING = 8'h01;
    localparam PS2_CMD_STAT_ACK = 8'hFA;
    localparam PS2_CMD_STAT_ERR = 8'hFE;

    // SMC
    reg [7:0]   smc_regnum;         // SMC register address; TBD move up the hierarchy
    reg  [1:0]  byteidx;            // SMC command/data stream - position index

    // PS2 port
    wire [7:0]  ps2k_rxcode;        // received byte from PS2 port
    wire        ps2k_rxcodevalid;   // validity flag of the PS2 port received byte

    // TX FIFO
    reg [7:0]   txfifo_wdata;        // byte to write into the TX FIFO
    reg         txfifo_enq;         // enqueue byte to the TX FIFO 
    reg         txfifo_clear;       // clear (reset) the TX FIFO buffer

    wire [7:0]  txfifo_rdata;           // TX FIFO output (rdata) byte, for PS2 port transmission
    wire        txfifo_deq;             // Dequeue current data from TX FIFO; this is driven from PS2 port 
                                        // when it finally consumes a byte for transmission
    
    // Status signals
    wire        txfifo_full;                 // TX FIFO is full?
    wire        txfifo_empty;                 // TX FIFO is empty?
    wire        ps2k_txcodevalid = !txfifo_empty;

    wire        ps2k_busy;              // PS2 port line is busy?
    wire        ps2k_acked;             // PS2 device has acked our transmission?
    wire        ps2k_errd;              // PS2 device has NOT acked out transmission?


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
        .cmd_tx_i (txfifo_rdata),         // command byte to send   
        .cmd_tx_v_i (ps2k_txcodevalid),         // send the command byte; recognized only when busy=0
        .cmd_tx_deq_o (txfifo_deq),         // byte for sending consumed, transmission starting.
        .busy (ps2k_busy),             // ongoing RX/TX (not accepting a new command now)
        .tx_acked_o (ps2k_acked),         // our TX commend byte was ACKed by device
        .tx_errd_o (ps2k_errd)           // we got a NACK at the end of command sending
    );

    // HACK
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? nora_slv_addr[7:0] : via1_slv_datard;
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? ps2k_rxcode : via1_slv_datard;

    // RX FIFO
    wire        rxfifo_full;               // RX FIFO is full?
    wire        rxfifo_enq = ps2k_rxcodevalid & !rxfifo_full;          // insert PS2 RX byte into the RX FIFO, only if not full.
    wire        rxfifo_empty;              // RX FIFO is empty?
    wire [7:0]  rxfifo_rdata;               // RX FIFO output byte (rdata); valid iff !rxfifo_empty
    reg         rxfifo_deq;                 // de-queue the RX FIFO rdata

    // RX FIFO to store incoming bytes from PS2 device (keyboard)
    fifo #(
        .BITWIDTH (8),          // bit-width of one data element = 8 bits = 1 byte
        .BITDEPTH (3)          // fifo keeps 2**BITDEPTH elements = 8 bytes deep
    ) kbdrxfifo
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn && !txfifo_clear),     // sync reset
        // I/O Write port
        .wport_i (ps2k_rxcode),          // Write Port Data
        .wenq_i (rxfifo_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (rxfifo_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (rxfifo_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (rxfifo_full),                 // FIFO is full?
        .empty_o (rxfifo_empty)                 // FIFO is empty?
    );    

    // TX FIFO to store outgoing bytes for transmission to PS2 device
    fifo #(
        .BITWIDTH (8),          // bit-width of one data element = 8 bits
        .BITDEPTH (2)          // fifo keeps 2**BITDEPTH elements = 4 bytes deep
    ) kbdtxfifo
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn  && !txfifo_clear),     // sync reset
        // I/O Write port
        .wport_i (txfifo_wdata),          // Write Port Data
        .wenq_i (txfifo_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (txfifo_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (txfifo_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (txfifo_full),                 // FIFO is full?
        .empty_o (txfifo_empty)                 // FIFO is empty?
    );    

    // current keyboard status byte for SMC read of register SMCREG_READ_PS2_KBD_STAT
    reg [7:0]  kbd_stat;

    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            txbyte_o <= 8'hFF;
            byteidx <= 2'b00;
            smc_regnum <= 8'h00;
            rxfifo_deq <= 0;
            txfifo_wdata <= 8'h00;
            txfifo_enq <= 0;
            kbd_stat <= PS2_CMD_STAT_IDLE;
            txfifo_clear <= 0;
        end else begin
            // clear one-off signals
            rxfifo_deq <= 0;
            txfifo_enq <= 0;
            txfifo_clear <= 0;

            if (ps2k_acked && txfifo_empty)
            begin
                kbd_stat <= PS2_CMD_STAT_ACK;
            end else if (ps2k_errd)
            begin
                kbd_stat <= PS2_CMD_STAT_ERR;
                txfifo_clear <= 1;
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
                                if (!txfifo_full)
                                begin
                                    ps2k_txcode <= rxbyte_i;
                                    txfifo_enq <= 1;
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
                            if (rxfifo_empty)
                            begin
                                txbyte_o <= 8'h00;
                            end else begin
                                txbyte_o <= rxfifo_rdata;
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
                            rxfifo_deq <= 1;
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

