/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * SPI Master
 */
module spi_master #(
    parameter NUM_TARGETS = 1                // number of supported targets (slaves), min 1.
)
(
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    // Prescaler for the SPI clock freq
    input [7:0]     prescaler_i,
    // SPI Master Peripheral signals
    output reg      spi_clk_o,
    output reg [NUM_TARGETS-1:0]   spi_csn_o,           // active low
    output          spi_mosi_o,
    output reg      spi_mosi_drive_o,
    input           spi_miso_i,
    // Target addressing
    input [NUM_TARGETS-1:0]   target_id_i,
    input           target_en_i,         // bus enable -> generates csn signal to the target
    // Data to send to the SPI bus to the addressed target
    input [7:0]     tx_byte_i,          // transmit data byte
    input           tx_en_i,            // flag: catch the transmit byte
    output          tx_ready_o,         // flag: it is possible to enqueue next tx byte now.
    // Received data from the SPI bus
    output [7:0]    rx_byte_o,          // received byte data
    output reg      rx_en_o             // flag: received a byte
);
// IMPLEMENTATION

    localparam IDLE = 0;                // no CSN, no commands.
    localparam ENTER_SELECT = 1;        // CSN is getting activated, delay to the first command
    localparam READY_TXDATA = 2;         // ready to get the TX byte for transmission
    localparam SHIFT_CLK_HI = 3;        // shifting, spi-clock shall become HI and rx-bit shall be captured
    localparam SHIFT_CLK_LO = 4;        // shifting, spi-clock shall become LO and tx-bit shall be set
    // localparam EXIT_SELECT = 5;         // CSN is getting de-activated, with a delay

    // registers
    reg [3:0]  fsm_state_r;         // state machine

    reg [7:0]  divider_r;           // clock output divider

    reg [2:0]  shift_cnt_r;         // bit shift counter
    reg [7:0]  txbuf_r;             // byte for transmit
    reg [7:0]  rxbuf_r;             // byte being received

    always @(posedge clk) 
    begin
        if (!resetn || !target_en_i)
        begin
            // in reset (system reset or no target request)
            fsm_state_r <= IDLE;
            shift_cnt_r <= 0;
            divider_r <= 0;
            spi_clk_o <= 0;
            spi_csn_o <= {NUM_TARGETS{1'b1}};
            // spi_mosi_o <= 0;
            spi_mosi_drive_o <= 0;
            // tx_ready_o <= 0;
            // rx_byte_o <= 0;
            rx_en_o <= 0;
            txbuf_r <= 0;
            rxbuf_r <= 0;
        end else begin
            // normal operation, target selected
            spi_csn_o <= ~target_id_i;
            // idle state
            rx_en_o <= 0;
            spi_mosi_drive_o <= 1;

            case (fsm_state_r)
                IDLE: 
                begin
                    spi_clk_o <= 0;
                    divider_r <= prescaler_i;
                    fsm_state_r <= ENTER_SELECT;
                end

                ENTER_SELECT:       // CSN is getting activated, delay to the first command
                begin
                    if (!divider_r)
                    begin
                        // divider is zero => done waiting pre-scaler => ready for tx
                        fsm_state_r <= READY_TXDATA;
                    end else begin
                        // divider running
                        divider_r <= divider_r - 1;
                    end
                end

                READY_TXDATA:       // ready to get the TX byte for transmission
                begin
                    // are there input data?
                    if (tx_en_i)
                    begin
                        txbuf_r <= tx_byte_i;
                        fsm_state_r <= SHIFT_CLK_HI;
                        divider_r <= prescaler_i;
                        shift_cnt_r <= 7;
                    end
                end

                SHIFT_CLK_HI:       // shifting, spi-clock shall become HI and rx-bit shall be captured
                begin
                    if (!divider_r)
                    begin
                        // divider done -> set clock hi
                        spi_clk_o <= 1;
                        // capture input MISO rx-bit to the buffer
                        rxbuf_r <= { rxbuf_r[6:0], spi_miso_i };        // shift left
                        // next start with clock lo
                        fsm_state_r <= SHIFT_CLK_LO;
                        divider_r <= prescaler_i;       // divider restart
                    end else begin
                        // divider running
                        divider_r <= divider_r - 1;
                    end
                end

                SHIFT_CLK_LO:       // shifting, spi-clock shall become LO and tx-bit shall be set
                begin
                    if (!divider_r)
                    begin
                        // divider done -> set clock low
                        spi_clk_o <= 0;
                        // set the next MOSI output bit by shifting the tx-buffer left
                        txbuf_r <= { txbuf_r[6:0], 1'b0 };
                        // all bits done?
                        if (shift_cnt_r)
                        begin
                            // no, still counting.
                            shift_cnt_r <= shift_cnt_r - 1;
                            // next start with clock hi
                            fsm_state_r <= SHIFT_CLK_HI;
                            divider_r <= prescaler_i;       // divider restart
                        end else begin
                            // yes (shift_cnt_r is zero now)!
                            // signalize that rx-byte is valid (just for 1cc)
                            rx_en_o <= 1;
                            // and accept next tx-byte
                            fsm_state_r <= READY_TXDATA;
                        end
                    end else begin
                        // divider running
                        divider_r <= divider_r - 1;
                    end
                end
            endcase
        end
    end

    // we are ready to accept next tx-byte just in the READY_TXDATA state:
    assign tx_ready_o = (fsm_state_r == READY_TXDATA);
    
    // MOSI outputs the MSB of txbuf (the shift register)
    assign spi_mosi_o = txbuf_r[7];             // SPI bus is MSB-first

    // rx-byte outputs the state of rx shift register
    assign rx_byte_o = rxbuf_r;

endmodule
