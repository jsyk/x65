/**
 * Host controller for PS2 keyboard.
 *
 */
module ps2_kbd_host (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    input           ck1us,      // 1us pulses
    // Generic Host interface:
    // Read from keyboard buffer (from RX FIFO)
    output [7:0]    kbd_rdata_o,      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
    output          kbd_rvalid_o,     // RX FIFO byte is valid? (= FIFO not empty?)
    input           kbd_rdeq_i,       // dequeu (consume) RX FIFO; allowed only iff kbd_rvalid==1
    // Keyboard reply status register, values:
    //      0x00 => idle (no transmission started)
    //      0x01 => transmission pending
    //      0xFA => ACK received
    //      0xFE => ERR received
    output reg [7:0] kbd_stat_o,
    // Write to keyboard:
    input [7:0]     kbd_wcmddata_i,           // byte for TX FIFO to send into PS2 keyboard
    input           kbd_enq_cmd1_i,           // enqueu 1Byte command
    input           kbd_enq_cmd2_i,           // enqueu 2Byte command+data
    // PS2 Keyboard port - FPGA pins
    input           PS2K_CLK,           // pin value
    input           PS2K_DATA,          // pin value
    output          PS2K_CLKDR,         // 1=drive PS2K_CLK to zero (L)
    output          PS2K_DATADR         // 1=drive PS2K_DATA to zero (L)
);
    // IMPLEMENTATION

    // values for output reg kbd_stat: (from PS2_CMD_STATUS : uint8_t):
    localparam PS2_CMD_STAT_IDLE = 8'h00;
    localparam PS2_CMD_STAT_PENDING = 8'h01;
    localparam PS2_CMD_STAT_ACK = 8'hFA;
    localparam PS2_CMD_STAT_ERR = 8'hFE;

    // PS2 port
    wire [7:0]  ps2k_rxcode;        // received byte from PS2 port
    wire        ps2k_rxcodevalid;   // validity flag of the PS2 port received byte

    // TX FIFO
    // reg [7:0]   txfifo_wdata;        // byte to write into the TX FIFO
    wire        txfifo_enq;         // enqueue byte to the TX FIFO 
    reg         txfifo_clear;       // clear (reset) the TX FIFO buffer

    wire [7:0]  txfifo_rdata;           // TX FIFO output (rdata) byte, for PS2 port transmission
    wire        txfifo_deq;             // Dequeue current data from TX FIFO; this is driven from PS2 port 
                                        // when it finally consumes a byte for transmission
    
    // Status signals
    wire        txfifo_full;                 // TX FIFO is full?
    wire        txfifo_empty;                 // TX FIFO is empty?
    reg         ps2k_txcodevalid;           // pass a byte from TX FIFO into PS2 port for sending?

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
    wire        rxfifo_enq;                 // insert PS2 RX byte into the RX FIFO
    wire        rxfifo_empty;              // RX FIFO is empty?
    wire [7:0]  rxfifo_rdata;               // RX FIFO output byte (rdata); valid iff !rxfifo_empty
    wire        rxfifo_deq;                 // de-queue the RX FIFO rdata

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
        .wport_i (kbd_wcmddata_i),          // Write Port Data
        .wenq_i (txfifo_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (txfifo_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (txfifo_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (txfifo_full),                 // FIFO is full?
        .empty_o (txfifo_empty)                 // FIFO is empty?
    );    


    // FSM state enum
    localparam TX_DEFAULT = 3'o0;                   // no TX ongoing, maybe just RX, or simple 1B command or data.
    localparam TX_2B_SEND_FIRST = 3'o1;             // 2B command+data sending: wait for the first byte being consumed (start sending)
    localparam TX_2B_WAIT_FIRST_REPLY = 3'o2;       // 2B command+data sending: the cmd byte has been sent, now waiting for a reply

    // FSM state
    reg [2:0]   fsm_state;

    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            fsm_state <= TX_DEFAULT;
            kbd_stat_o <= PS2_CMD_STAT_IDLE;
            // txfifo_wdata <= 8'h00;
            // txfifo_enq <= 0;
            txfifo_clear <= 0;
            ps2k_txcodevalid <= 0;          // pass a byte from TX FIFO into PS2 port?
            // rxfifo_deq <= 0;
        end else begin
            // clear one-off signals
            // txfifo_enq <= 0;
            txfifo_clear <= 0;
            ps2k_txcodevalid <= !txfifo_empty;

            // have we sent something and waiting for a reply?
            if (kbd_stat_o == PS2_CMD_STAT_PENDING)
            begin
                // yes; 
                
                // is there error in sending - missing ack bit from device?
                // if (ps2k_errd)
                // begin
                //     // yes -> cancel
                //     kbd_stat_o <= PS2_CMD_STAT_ERR;
                //     txfifo_clear <= 1;
                //     fsm_state <= TX_DEFAULT;
                // end

                // are we receiving a reply?
                if (ps2k_rxcodevalid)
                begin
                    // yes;
                    // is the reply an error code or ack code?
                    if (ps2k_rxcode == PS2_CMD_STAT_ERR)
                    begin
                        // anything else | error code -> set status and clear any further tx-bytes in the TX FIFO
                        kbd_stat_o <= PS2_CMD_STAT_ERR;
                        txfifo_clear <= 1;
                        fsm_state <= TX_DEFAULT;
                    end else if (ps2k_rxcode == PS2_CMD_STAT_ACK)
                    begin
                        // ack reply code - OK;
                        // are there any more bytes in the TX FIFO ?
                        if (fsm_state == TX_2B_WAIT_FIRST_REPLY)
                        begin
                            // yes, there should be one more (data) byte in TX FIFO;
                            // this ACK is noted internally, but thrown away (not reported to CPU).
                            // Go back to the default state, this unblocks sending of the remaining data 
                            // byte from TX FIFO, and normal processing of the reply, when it arrives.
                            fsm_state <= TX_DEFAULT;
                        end else begin
                            // no, this is the last reply in sequence -> remember
                            kbd_stat_o <= PS2_CMD_STAT_ACK;
                        end
                    end
                end
            end

            case (fsm_state)
                TX_DEFAULT:
                begin
                    if (kbd_enq_cmd1_i)
                    begin
                        // enqueue 1-byte command (recommended flow)
                        kbd_stat_o <= PS2_CMD_STAT_PENDING;
                    end else if (kbd_enq_cmd2_i)
                    begin
                        // enqueuing 2-byte command & data
                        kbd_stat_o <= PS2_CMD_STAT_PENDING;
                        fsm_state <= TX_2B_SEND_FIRST;
                    end
                end

                TX_2B_SEND_FIRST:           // 2B command+data sending: wait for the first byte being consumed (start sending)
                begin
                    if (txfifo_deq)
                    begin
                        // TX FIFO byte consumed by PS2 port
                        fsm_state <= TX_2B_WAIT_FIRST_REPLY;
                    end
                end

                TX_2B_WAIT_FIRST_REPLY:     // 2B command+data sending: the cmd byte has been sent, now waiting for a reply
                begin
                    // block any further sending from TX FIFO until we get a reply
                    ps2k_txcodevalid <= 0;
                    // TBD: check for timeout!!
                end
            endcase
        end
        
    end

    // generate simple outputs
    assign kbd_rdata_o = rxfifo_empty ? 8'h00 : rxfifo_rdata;      // RX FIFO byte from PS2 keyboard, or 0x00 in case !kbd_rvalid
    assign kbd_rvalid_o = !rxfifo_empty;     // RX FIFO byte is valid? (= FIFO not empty?)
    assign rxfifo_deq = kbd_rdeq_i && !rxfifo_empty;
    
    // assign txfifo_wdata = kbd_wcmddata_i;
    assign txfifo_enq = kbd_enq_cmd1_i | kbd_enq_cmd2_i;

    // insert PS2 RX byte into the RX FIFO, only if not full and not waiting for the first reply in a 2-byte sequence.
    // If it is the first reply in a 2-byte sequence, then it should be ACK, and that gets noted but NOT inserted in the FIFO.
    // However, if it is anything else than ACK, then we should process in the FIFO as usual.
    assign rxfifo_enq = ps2k_rxcodevalid & !rxfifo_full & ((fsm_state != TX_2B_WAIT_FIRST_REPLY) | (ps2k_rxcode != PS2_CMD_STAT_ACK));

endmodule

