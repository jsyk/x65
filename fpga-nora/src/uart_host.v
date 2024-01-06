/* Copyright (c) 2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * UART Host Controller
 *
 * TBD: HWFlowCtrl with RTS/CTS!!
 */
module uart_host #(
    parameter RXFIFO_DEPTH_BITS = 4,
    parameter TXFIFO_DEPTH_BITS = 4
) (
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    //
    // UART INTERFACE
    // UART RX/TX signal to the FPGA pin
    input           rx_pin_i,
    output          tx_pin_o,
    output          txde_o,              // tx drive enable, active high
    input           cts_pin_i,
    output          rts_pin_o,
    //
    // REGISTER INTERFACE
    output [7:0]    reg_d_o,            // read data output from the core (from the CONTROL or DATA REG)
    input  [7:0]    reg_d_i,            // write data input to the core (to the CONTROL or DATA REG)
    input           reg_wr_i,           // write signal
    input           reg_rd_i,           // read signal
    input           reg_cs_ctrl_i,           // target register select: CTRL REG
    input           reg_cs_stat_i,            // target register select: STAT REG
    input           reg_cs_data_i,            // target register select: DATA REG (FIFO)
    output          irq_o               // IRQ output, active high
);
    // IMPLEMENTATION

    reg ua_cken;           // from prescaler baud rate ticks
    reg parity_type_r;
    reg parity_en_r;

    // byte from uart_rx
    wire [7:0] ua_rx_byte;
    wire ua_rx_en;
    wire frame_err, parity_err;

    uart_rx ua_rx
    (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        // Prescaled rx-clock
        .uart_cken_i (ua_cken),              // 16x the UART transmit baud-rate, 1T pulses
        // Parity configuration. Should be held constant normally, and changed just in idle.
        .parity_type_i (parity_type_r),          // which type of parity bit to expect: 0=even, 1=odd.
        .parity_en_i (parity_en_r),            // enable the receive of parity bit (1), or no parity (0)
        // Data received
        .rx_byte_o (ua_rx_byte),          // received data byte
        .rx_en_o (ua_rx_en),            // flag: got byte
        .frame_err_o (frame_err),        // 1T flag indicates framing error (hi start bit or low stop bit)
        .parity_err_o (parity_err),       // 1T flag indicates parity error (if parity is enabled)
        // Input RX signal from the FPGA pin
        .rx_pin_i (rx_pin_i)
    );

    // byte to uart_tx
    wire [7:0] ua_tx_byte;
    wire ua_tx_en;
    wire ua_tx_ready;

    uart_tx ua_tx
    (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        // Prescaled tx-clock
        .uart_cken_i (ua_cken),              // 16x the UART transmit baud-rate, 1T pulses
        // Parity configuration
        .parity_type_i (parity_type_r),          // which type of parity bit to transmit: 0=even, 1=odd.
        .parity_en_i (parity_en_r),            // enable the generation of parity bit (1), or no parity (0)
        // Data to send to the TXD
        .tx_byte_i (ua_tx_byte),          // transmit data byte
        .tx_en_i (ua_tx_en),            // flag: catch the transmit byte
        .tx_ready_o (ua_tx_ready),         // flag: it is possible to enqueue next tx byte now.
        // Output TX signal to the FPGA pin
        .tx_pin_o (tx_pin_o),
        .txde_o (txde_o)              // tx drive enable, active high
    );


    // write enqueue signal to the TX FIFO: when Writing to the DATA REG
    wire txf_enq = reg_wr_i && reg_cs_data_i && !txf_full;
    // read dequeue signal for the TXFIFO: when we request UART-TX and it is Ready now.
    wire txf_deq = ua_tx_en && ua_tx_ready;
    // status output from TX FIFO
    wire txf_full;
    wire txf_empty;
    // we request SPI-TX as soon as TX-FIFO is non-empty
    assign ua_tx_en = !txf_empty;

    // Transmission bytes FIFO
    fifo  #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (TXFIFO_DEPTH_BITS)          // fifo keeps 2**BITDEPTH elements
    ) txfifo
    (
        // Global signals
        .clk6x (clk),      // 48MHz
        .resetn (resetn),     // sync reset
        // I/O Write port
        .wport_i (reg_d_i),          // Write Port Data
        .wenq_i (txf_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (ua_tx_byte),          // Read port data: valid any time empty_o=0
        .rdeq_i (txf_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (txf_full),                 // FIFO is full?
        .empty_o (txf_empty),                // FIFO is empty?
        .count_o ()       // count of elements in the FIFO now; mind the width of the reg!
    );


    // status output from RX FIFO
    wire rxf_full;
    wire rxf_empty;
    
    // read (dequeue) data from the RX FIFO: when Reading from the DATA REG
    wire rxf_deq = reg_rd_i && reg_cs_data_i && !rxf_empty;
    wire [7:0] rxf_rdata;

    // Receive bytes FIFO
    fifo  #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (RXFIFO_DEPTH_BITS)          // fifo keeps 2**BITDEPTH elements
    ) rxfifo
    (
        // Global signals
        .clk6x (clk),      // 48MHz
        .resetn (resetn),     // sync reset
        // I/O Write port
        .wport_i (ua_rx_byte),          // Write Port Data
        .wenq_i (ua_rx_en),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (rxf_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (rxf_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (rxf_full),                 // FIFO is full?
        .empty_o (rxf_empty),                // FIFO is empty?
        .count_o ()       // count of elements in the FIFO now; mind the width of the reg!
    );


    // control register
    reg [2:0]   baudrate_r;
    reg         ena_hwflow_r;
    reg         ena_irq_rx_r;
    reg         ena_irq_tx_r;

    wire [7:0] reg_ctrl = { ena_irq_tx_r, ena_irq_rx_r, ena_hwflow_r, parity_type_r, parity_en_r, baudrate_r };

    // status register
    reg         parity_err_flag_r;
    reg         framing_err_flag_r;

    wire [7:0] reg_stat = { rxf_empty, cts_pin_i, parity_err_flag_r, framing_err_flag_r, txf_full, txf_empty, rxf_full, 1'b0 };

    // calculate REG READ output:
    assign reg_d_o = (reg_cs_ctrl_i) ? reg_ctrl : 
                     (reg_cs_stat_i) ? reg_stat : rxf_rdata;

    // CONTROL REGISTER HANDLING

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // in reset
            baudrate_r <= 3'b100;       // 115200 Baud
            parity_en_r <= 0;
            parity_type_r <= 0;
            ena_hwflow_r <= 0;
            ena_irq_rx_r <= 0;
            ena_irq_tx_r <= 0;
            parity_err_flag_r <= 0;
            framing_err_flag_r <= 0;
        end else begin
            // normal oper
            if (reg_wr_i && reg_cs_ctrl_i)
            begin
                // CPU writing to CONTROL REG
                baudrate_r <= reg_d_i[2:0];
                parity_en_r <= reg_d_i[3];
                parity_type_r <= reg_d_i[4];
                ena_hwflow_r <= reg_d_i[5];
                ena_irq_rx_r <= reg_d_i[6];
                ena_irq_tx_r <= reg_d_i[7];
            end
            if (reg_wr_i && reg_cs_stat_i)
            begin
                // CPU writing to STATUS REG
                framing_err_flag_r <= reg_d_i[4];
                parity_err_flag_r <= reg_d_i[5];
            end
            // update err flags from uart_rx
            if (parity_err)
            begin
                parity_err_flag_r <= 1;
            end
            if (frame_err)
            begin
                framing_err_flag_r <= 1;
            end
        end
    end

    assign irq_o = (ena_irq_rx_r && (!rxf_empty || parity_err_flag_r || framing_err_flag_r))
                    || (ena_irq_tx_r && !txf_full);

    // PRESCALER
    reg  [8:0]  presc_counter_r;
    reg  [8:0]  prescaler_top;

    // generate prescaler value
    always @(baudrate_r)
    begin
        prescaler_top = 9'h1FF;
        case (baudrate_r)
            3'b000:     prescaler_top = 9'h1FF;         // reserved!
            3'b001:     prescaler_top = 9'h1FF;         // reserved!
            3'b010:     prescaler_top = 9'd312;         // 9600 Bd
            3'b011:     prescaler_top = 9'd51;         // 57600 Bd
            3'b100:     prescaler_top = 9'd25;          // 115200 Bd <- default
            3'b101:     prescaler_top = 9'd12;          // 230400 Bd
            3'b110:     prescaler_top = 9'd1;          // 1000000 Bd
            3'b111:     prescaler_top = 9'd0;          // 3000000 Bd
        endcase
    end

    always @(posedge clk) 
    begin
        ua_cken <= 0;

        if (!resetn)
        begin
            presc_counter_r <= prescaler_top;
        end else begin
            // normal op. - decrement the counter
            presc_counter_r <= presc_counter_r - 1;

            // reached zero already?
            if (presc_counter_r == 0)
            begin
                // yes -> reset to the TOP
                presc_counter_r <= prescaler_top;
                // generate uart tick for 1T
                ua_cken <= 1;
            end
        end
        
    end


endmodule
