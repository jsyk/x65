/* Copyright (c) 2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
module spi_master_hostctrl
#(
    parameter NUM_TARGETS = 1,                // number of supported targets (slaves), min 1.
    parameter RXFIFO_DEPTH_BITS = 4,
    parameter TXFIFO_DEPTH_BITS = 4
) (
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    //
    // SPI Master Peripheral signals
    output          spi_clk_o,
    output   [NUM_TARGETS-1:0]   spi_csn_o,           // active low
    output          spi_mosi_o,
    output          spi_mosi_drive_o,
    input           spi_miso_i,
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

    // SPI MASTER INTERFACE
    // Prescaler for the SPI clock freq
    wire [7:0]    sm_prescaler;
    // Target addressing
    wire [NUM_TARGETS-1:0]   sm_target_id;
    wire          sm_target_en;         // bus enable -> generates csn signal to the target
    // Data to send to the SPI bus to the addressed target
    wire [7:0]    sm_tx_byte;          // transmit data byte
    wire          sm_tx_en;            // flag: catch the transmit byte
    wire           sm_tx_ready;         // flag: it is possible to enqueue next tx byte now.
    // Received data from the SPI bus
    wire [7:0]     sm_rx_byte;          // received byte data
    wire           sm_rx_en;             // flag: received a byte
    wire           sm_rxtx_busy;        // flag: ongoing SPI activity


    spi_master #(
        .NUM_TARGETS (NUM_TARGETS)                // number of supported targets (slaves), min 1.
    ) spim
    (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        // Prescaler for the SPI clock freq
        .prescaler_i (sm_prescaler),
        // SPI Master Peripheral signals
        .spi_clk_o (spi_clk_o),
        .spi_csn_o (spi_csn_o),           // active low
        .spi_mosi_o (spi_mosi_o),
        .spi_mosi_drive_o (spi_mosi_drive_o),
        .spi_miso_i (spi_miso_i),
        // Target addressing
        .target_id_i (sm_target_id),
        .target_en_i (sm_target_en),         // bus enable -> generates csn signal to the target
        // Data to send to the SPI bus to the addressed target
        .tx_byte_i (sm_tx_byte),          // transmit data byte
        .tx_en_i (sm_tx_en),            // flag: catch the transmit byte
        .tx_ready_o (sm_tx_ready),         // flag: it is possible to enqueue next tx byte now.
        // Received data from the SPI bus
        .rx_byte_o (sm_rx_byte),          // received byte data
        .rx_en_o (sm_rx_en),            // flag: received a byte
        .rxtx_busy_o (sm_rxtx_busy)           // flag: ongoing SPI activity
    );



    spi_host #(
        .NUM_TARGETS (NUM_TARGETS),                // number of supported targets (slaves), min 1.
        .RXFIFO_DEPTH_BITS (RXFIFO_DEPTH_BITS),
        .TXFIFO_DEPTH_BITS (TXFIFO_DEPTH_BITS)
    ) spihst (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        //
        // SPI MASTER INTERFACE
        // Prescaler for the SPI clock freq
        .sm_prescaler_o (sm_prescaler),
        // Target addressing
        .sm_target_id_o (sm_target_id),
        .sm_target_en_o (sm_target_en),         // bus enable -> generates csn signal to the target
        // Data to send to the SPI bus to the addressed target
        .sm_tx_byte_o (sm_tx_byte),          // transmit data byte
        .sm_tx_en_o (sm_tx_en),            // flag: catch the transmit byte
        .sm_tx_ready_i (sm_tx_ready),         // flag: it is possible to enqueue next tx byte now.
        // Received data from the SPI bus
        .sm_rx_byte_i (sm_rx_byte),          // received byte data
        .sm_rx_en_i (sm_rx_en),             // flag: received a byte
        .sm_rxtx_busy_i (sm_rxtx_busy),        // flag: ongoing SPI activity
        //
        // REGISTER INTERFACE
        .reg_d_o (reg_d_o),            // read data output from the core (from the CONTROL or DATA REG)
        .reg_d_i (reg_d_i),            // write data input to the core (to the CONTROL or DATA REG)
        .reg_wr_i (reg_wr_i),           // write signal
        .reg_rd_i (reg_rd_i),           // read signal
        // .reg_ad_i (reg_ad_i)            // target register select: 0=CONTROL REG, 1=DATA REG.
        .spireg_cs_ctrl_i (spireg_cs_ctrl_i),
        .spireg_cs_stat_i (spireg_cs_stat_i),
        .spireg_cs_data_i (spireg_cs_data_i)
    );


endmodule
