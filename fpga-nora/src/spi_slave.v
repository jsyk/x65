/**
 * SPI Slave (Target) - for ICD function.
 */
module spi_slave (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // SPI Slave signals
    input           spi_clk_i,
    input           spi_csn_i,
    input           spi_mosi_i,
    output reg      spi_miso_o,
    output reg      spi_miso_drive_o,
    // Received data
    output reg [7:0] rx_byte_o,     // received byte data
    output reg      rx_hdr_en_o,    // flag: received first byte
    output reg      rx_db_en_o,     // flag: received next byte
    // Send data
    input [7:0]     tx_byte_i,      // transmit byte
    input           tx_en_i,        // flag: catch the transmit byte
    // Histogram sample data
    input           fast_clk,
    input  [4:0]    histidx_i,
    output [15:0]   histcnt_o,
    input           run_hist_i,
    input           clear_hist_i
);
// IMPLEMENTATION
    // synced input values
    reg     prev_sck_r;     // 2x registered spi_clk_i
    reg     sck_r;          // registered spi_clk_i
    reg     scsn_r;         // registered spi_csn_i
    reg     smosi_r;        // registered spi_mosi_i
    reg     prev1_smosi_r, prev2_smosi_r;

    // flag indicates rising edge on SCK input
    reg     rising_sck;

    // TX output shift register - updated at specific time
    reg [7:0]  tx_data_shift;
    // TX output buffer - updated by user logic at any time
    reg [7:0]  tx_buffer_r;
    // RX input shift register
    reg [7:0]  rx_data_shift;

    // bit counter
    reg [3:0]   counter_r;
    // byte "counter"
    reg         first_byte;         // to mark the first RX byte after CSN
    
    // sync the input signals to the system clock domain
    always @(posedge clk6x)
    begin
        // store input signals
        sck_r <= spi_clk_i;
        prev_sck_r <= sck_r;
        scsn_r <= spi_csn_i;
        smosi_r <= spi_mosi_i;
        prev1_smosi_r <= smosi_r;
        prev2_smosi_r <= prev1_smosi_r;

        // detect SCK rising edge?
        // rising_sck <= !prev_sck_r && spi_clk_i;
        rising_sck <= !prev_sck_r && sck_r;
    end

    always @(posedge clk6x)
    begin
        rx_hdr_en_o <= 0;
        rx_db_en_o <= 0;

        if (!resetn || scsn_r)
        begin
            // System Reset or Chip select not active
            spi_miso_drive_o <= 0;
            rx_hdr_en_o <= 0;
            rx_db_en_o <= 0;
            // while deselcted keep assigning the user tx buffer
            // so that we start with correct bit already
            tx_data_shift <= tx_buffer_r;
            spi_miso_o <= tx_buffer_r[7];
            counter_r <= 0;
            first_byte <= 1;
        end else begin
            // SPI_SCN_I is active;
            // drive the MISO as an output in toplevel:
            spi_miso_drive_o <= 1;

            // shifted eight bits already?
            if (counter_r[3])
            begin
                // yes; send RX data to user logic
                rx_byte_o <= rx_data_shift;
                rx_hdr_en_o <= first_byte;
                rx_db_en_o <= !first_byte;
                // copy from TX buffer to the TX shift register
                tx_data_shift <= tx_buffer_r;
                // and immediately update the output reg. signal (!)
                spi_miso_o <= tx_buffer_r[7];
                // reset counter - set next byte (until CSN goes high):
                counter_r <= 0;
                first_byte <= 0;
            end else begin
                if (rising_sck)
                begin
                    // MOSI: store the incoming SI bit to RX shift register, MSB first
                    rx_data_shift <= { rx_data_shift[6:0], prev2_smosi_r };
                    // inc the bit counter
                    counter_r <= counter_r + 4'd1;
                    // MISO: update the output bit register (SO) from TX shift register, MSB:
                    spi_miso_o <= tx_data_shift[6];
                    // ... and shift the TX register; LSB: pull bit from user TX buffer, 
                    // maybe it is already correct and that will minimize SO transition.
                    tx_data_shift <= { tx_data_shift[6:0], tx_buffer_r[7] };
                end
            end
        end

        // update output data byte (for MISO) in the internal buffer at any time
        if (tx_en_i)
        begin
            tx_buffer_r <= tx_byte_i;
        end
    end 

    // sampling register for spi_mosi_i at the 240MHz clock
    reg [31:0]      samp_smosi_r;
    // holding register - written at the spi_clk rising_edge
    reg [31:0]      hold_smosi_r;
    // histogram counters
    reg [15:0]      histcnt_r [0:31];
    // flag to update the histogram counters
    reg             upd_hist_r;
    // reference value that was sampled to the spi_slave.
    reg             ref_smosi_val_r;


    // sync the input signals to the system clock domain
    always @(posedge fast_clk)
    begin
        samp_smosi_r <= { samp_smosi_r[30:0], spi_mosi_i };
    end

    always @(posedge clk6x)
    begin
        upd_hist_r <= 0;

        if (!resetn || scsn_r)
        begin
            hold_smosi_r <= 0;
            ref_smosi_val_r <= 0;
        end else begin
            // SPI_SCN_I is active;
            // shifted eight bits already?
            if (counter_r[3])
            begin
                // end of byte
            end else begin
                if (rising_sck)
                begin
                    hold_smosi_r <= samp_smosi_r;
                    upd_hist_r <= run_hist_i;
                    ref_smosi_val_r <= prev2_smosi_r;
                end
            end

            // update the histogram memory?
            // if (upd_hist_r)
            // begin
            //     if (hold_smosi_r[0] != ref_smosi_val_r)
            //     begin
            //         histcnt_r[0] <= histcnt_r[0] + 1;
            //     end
            // end
        end
    end

    genvar i;
    
    generate
        for (i = 0; i < 32; i++) 
        begin
            always @(posedge clk6x)
            begin
                // update the histogram memory?
                if (upd_hist_r)
                begin
                    if ((i == 0) || (hold_smosi_r[i] != ref_smosi_val_r))
                    begin
                        if (histcnt_r[i] != 16'hFFFF)       // saturate
                        begin
                            histcnt_r[i] <= histcnt_r[i] + 1;
                        end
                    end
                end
                if (clear_hist_i)
                begin
                    histcnt_r[i] <= 0;
                end
            end
        end
    endgenerate

    assign histcnt_o = histcnt_r[histidx_i];

    // read from ROM
    // always @(posedge clk6x) 
    // begin
    //     histcnt_o <= histcnt_r[histidx_i];
    // end

endmodule
