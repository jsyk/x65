/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * SPI Host controller implements the MEM/IO register interface between the CPU (NORA Slave Bus)
 * and the SPI Master core, which is actually driving FPGA pins.
 *
 * TBD: IRQ support
 *
    Address         Reg.name            Bits        Description
    $9F52           N_SPI_CTRL
                                        [7:6] = reserved, 0
                                        TBD: IRQ???
                                        [5:3] = set the SPI speed - SCK clock frequency:
                                                000 = 100kHz
                                                001 = 400kHz
                                                010 = 1MHz
                                                011 = 8MHz
                                                100 = 24MHz
                                                other = reserved.
                   
                                        [2:0] = set the target SPI slave (1-7), or no slave (CS high) when 0.
                                                000 = no slave (all deselect)
                                                001 = UNIFIED ROM = NORA's SPI-Flash
                                                010 = UEXT SPI-Bus
                                                other = reserved.

    $9F53           N_SPI_STAT                      SPI Status
                                        [0] = Is RX FIFO empty?
                                        [1] = Is RX FIFO full?
                                        [2] = Is TX FIFO empty?
                                        [3] = Is TX FIFO full?
                                        [4] = reserved, 0
                                        [5] = reserved, 0
                                        [6] = reserved, 0
                                        [7] = Is BUSY - is TX/RX in progress?

    $9F54           N_SPI_DATA                      Reading dequeues data from the RX FIFO.
                                                    Writing enqueues to the TX FIFO.
 */
module spi_host #(
    parameter NUM_TARGETS = 1,                // number of supported targets (slaves), min 1.
    // FIFO depth vs ICE40: up to 3b => RAM in LUTS, from 4b to 9b => RAM in 3*BlockRAM, from 10b => add 2*BlockRAM
    parameter RXFIFO_DEPTH_BITS = 4,
    parameter TXFIFO_DEPTH_BITS = 4
) (
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    //
    // SPI MASTER INTERFACE
    // Prescaler for the SPI clock freq
    output reg [7:0]    sm_prescaler_o,
    // Target addressing
    output reg [NUM_TARGETS-1:0]   sm_target_id_o,
    output          sm_target_en_o,         // bus enable -> generates csn signal to the target
    // Data to send to the SPI bus to the addressed target
    output [7:0]    sm_tx_byte_o,          // transmit data byte
    output          sm_tx_en_o,            // flag: catch the transmit byte
    input           sm_tx_ready_i,         // flag: it is possible to enqueue next tx byte now.
    // Received data from the SPI bus
    input [7:0]     sm_rx_byte_i,          // received byte data
    input           sm_rx_en_i,             // flag: received a byte
    input           sm_rxtx_busy_i,        // flag: ongoing SPI activity
    //
    // REGISTER INTERFACE
    output [7:0]    reg_d_o,            // read data output from the core (from the CONTROL or DATA REG)
    input  [7:0]    reg_d_i,            // write data input to the core (to the CONTROL or DATA REG)
    input           reg_wr_i,           // write signal
    input           reg_rd_i,           // read signal
    // input           reg_ad_i            // target register select: 0=CONTROL REG, 1=DATA REG.
    input           spireg_cs_ctrl_i,
    input           spireg_cs_stat_i,
    input           spireg_cs_data_i
);
    // IMPLEMENTATION

    // write enqueue signal to the TX FIFO: when Writing to the DATA REG
    wire txf_enq = reg_wr_i && spireg_cs_data_i && !txf_full;
    // read dequeue signal for the TXFIFO: when we request SPI-TX and it is Ready now.
    wire txf_deq = sm_tx_en_o && sm_tx_ready_i;
    // status output from TX FIFO
    wire txf_full;
    wire txf_empty;
    // we request SPI-TX as soon as TX-FIFO is non-empty
    assign sm_tx_en_o = !txf_empty;

    // Transmission bytes FIFO
    fifo  #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (TXFIFO_DEPTH_BITS)          // fifo keeps 2**BITDEPTH elements
    ) txfifo
    (
        // Global signals
        .clk6x (clk),      // 48MHz
        .resetn (resetn && sm_target_en_o),     // sync reset
        // I/O Write port
        .wport_i (reg_d_i),          // Write Port Data
        .wenq_i (txf_enq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (sm_tx_byte_o),          // Read port data: valid any time empty_o=0
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
    wire rxf_deq = reg_rd_i && spireg_cs_data_i && !rxf_empty;
    wire [7:0] rxf_rdata;

    // Receive bytes FIFO
    fifo  #(
        .BITWIDTH (8),          // bit-width of one data element
        .BITDEPTH (RXFIFO_DEPTH_BITS)          // fifo keeps 2**BITDEPTH elements
    ) rxfifo
    (
        // Global signals
        .clk6x (clk),      // 48MHz
        .resetn (resetn && sm_target_en_o),     // sync reset
        // I/O Write port
        .wport_i (sm_rx_byte_i),          // Write Port Data
        .wenq_i (sm_rx_en_i),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o (rxf_rdata),          // Read port data: valid any time empty_o=0
        .rdeq_i (rxf_deq),                 // Dequeue current data from FIFO
        // Status signals
        .full_o (rxf_full),                 // FIFO is full?
        .empty_o (rxf_empty),                // FIFO is empty?
        .count_o ()       // count of elements in the FIFO now; mind the width of the reg!
    );

    // STATUS_REG contents:
    wire [7:0] statusr = { sm_rxtx_busy_i, 3'b000, txf_full, txf_empty, rxf_full, rxf_empty };

    // CONTROL_REG contents:
    wire [7:0] controlr = { 2'b00, slave_speed_r, slave_addr_r };

    // calculate REG READ output:
    // AD = 1 -> RX FIFO output data
    // AD = 0 -> STATUS REG
    assign reg_d_o = (spireg_cs_data_i) ? rxf_rdata : 
                        (spireg_cs_ctrl_i) ? controlr : 
                        statusr;


    // CONTROL REGISTER HANDLING
    reg [2:0] slave_addr_r;
    reg [2:0] slave_speed_r;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // in reset
            slave_addr_r <= 0;
            slave_speed_r <= 0;
        end else begin
            // normal oper
            if (reg_wr_i && spireg_cs_ctrl_i)
            begin
                // CPU writing to CONTROL REG
                slave_addr_r <= reg_d_i[2:0];
                slave_speed_r <= reg_d_i[5:3];
            end
        end
    end

    // SPI master is enabled just when the slave address is non-zero
    assign sm_target_en_o = (slave_addr_r != 3'b000);

    integer i;
    // generate chip-select from slave address
    always @(slave_addr_r)
    begin
        sm_target_id_o = 0;
        
        for (i = 1; i <= NUM_TARGETS; i = i + 1)
        begin
            if (slave_addr_r == i)
            begin
                sm_target_id_o[i-1] = 1;
            end
        end
    end

    // generate prescaler value
    always @(slave_speed_r)
    begin
        sm_prescaler_o = 8'hFF;
        case (slave_speed_r)
            3'b000:     sm_prescaler_o = 8'd240;         // 100kHz
            3'b001:     sm_prescaler_o = 8'd60;         // 400 kHz
            3'b010:     sm_prescaler_o = 8'd24;         // 1MHz
            3'b011:     sm_prescaler_o = 8'h03;         // 8MHz
            3'b100:     sm_prescaler_o = 8'h00;         // 24Mhz
        endcase
    end

endmodule
