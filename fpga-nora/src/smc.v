/**
 * System Management Controller defined by CX16
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

    // SMC / I2C registers
    parameter SMCREG_READ_KBD_BUF = 8'h07;
    parameter SMCREG_READ_PS2_KBD_STAT = 8'h18;
    parameter SMCREG_SEND_PS2_KBD_CMD = 8'h19;

    reg [7:0]   smc_regnum;         // SMC register address

    // I2C bus interface signals
    wire      devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    wire      rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    wire [7:0]  rxbyte;          // the received byte for device
    wire        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    reg  [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    wire       txbyte_deq;       // the txbyte has been consumed (1T)
    // output reg      tx_nacked_o         // master NACKed the last byte!
    reg  [1:0]  byteidx;

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

    wire [7:0]  ps2k_code;
    wire        ps2k_codevalid;


    // PS2 Keyboard Port
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
        .code_rx_o (ps2k_code),       // received scan-code
        .code_rx_v_o (ps2k_codevalid),       // scan-code valid
        // Host-to-Device (TX) interface
        .cmd_tx_i (8'h00),         // command byte to send   
        .cmd_tx_v_i (1'b0),         // send the command byte; recognized only when busy=0
        .busy (),             // ongoing RX/TX (not accepting a new command now)
        .tx_acked_o (),         // our TX commend byte was ACKed by device
        .tx_errd_o ()           // we got a NACK at the end of command sending
    );

    // HACK
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? nora_slv_addr[7:0] : via1_slv_datard;
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? ps2k_code : via1_slv_datard;

    wire kbdfifo_full;
    wire ps2k_enq = ps2k_codevalid & !kbdfifo_full;
    wire kbdfifo_empty;
    reg kbdfifo_deq;
    wire [7:0] kbdfifo_rdata;

    fifo #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (3)          // fifo keeps 2**BITDEPTH elements
    ) kbdfifo
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // I/O Write port
        .wport_i (ps2k_code),          // Write Port Data
        .wenq_i (ps2k_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (kbdfifo_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (kbdfifo_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (kbdfifo_full),                 // FIFO is full?
        .empty_o (kbdfifo_empty)                 // FIFO is empty?
    );    


    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            txbyte <= 8'hFF;
            byteidx <= 2'b00;
            smc_regnum <= 8'h00;
            kbdfifo_deq <= 0;
        end else begin
            // clear one-off signals
            kbdfifo_deq <= 0;

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
                    end
                    
                    byteidx <= byteidx + 1;
                end

                if (rw_bit)         // I2C Read?
                begin
                    // reading from the slave -> we will transmit
                    case (smc_regnum)
                        SMCREG_READ_KBD_BUF:
                        begin
                            if (kbdfifo_empty)
                            begin
                                txbyte <= 8'h00;
                            end else begin
                                txbyte <= kbdfifo_rdata;
                            end
                        end

                        SMCREG_READ_PS2_KBD_STAT:
                        begin
                            txbyte <= 8'hFA;
                        end
                    endcase

                    if (txbyte_deq)
                    begin
                        byteidx <= byteidx + 1;
                        if ((smc_regnum == SMCREG_READ_KBD_BUF) && (txbyte != 8'h00))
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

