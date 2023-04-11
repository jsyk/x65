`timescale 1ns/100ps

module tb_spi_slave ();

    // Global signals
    reg           clk6x;      // 48MHz
    reg           resetn;     // sync reset
    // SPI Slave signals
    reg           spi_clk_i;
    reg           spi_csn_i;
    reg           spi_mosi_i;
    wire      spi_miso_o;
    wire      spi_miso_drive_o;
    // Received data
    wire [7:0] rx_byte_o;     // received byte data
    wire      rx_hdr_en_o;    // flag: received first byte
    wire      rx_db_en_o;     // flag: received next byte
    // Send data
    reg  [7:0]     tx_byte_i;      // transmit byte
    reg           tx_en_i;         // flag: catch the transmit byte


    spi_slave dut0 (
        // Global signals
        clk6x,      // 48MHz
        resetn,     // sync reset
        // SPI Slave signals
        spi_clk_i,
        spi_csn_i,
        spi_mosi_i,
        spi_miso_o,
        spi_miso_drive_o,
        // Received data
        rx_byte_o,     // received byte data
        rx_hdr_en_o,    // flag: received first byte
        rx_db_en_o,     // flag: received next byte
        // Send data
        tx_byte_i,      // transmit byte
        tx_en_i         // flag: catch the transmit byte
    );

    // Clock Generator
    initial clk6x = 1'b0;
    always #(20)
    begin
        clk6x = ~clk6x;
    end

    integer j;
    integer k;

    reg [7:0] sending_byte;

    initial
    begin
        spi_csn_i = 1;
        spi_clk_i = 0;
        spi_mosi_i = 0;
        // tx_byte_i = 0;
        // tx_en_i = 0;
        // RESET ACTIVE
        resetn = 1'b0;
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end
        // RESET INACTIVE
        resetn = 1'b1;
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end

        // tx_byte_i = 8'h55;
        // tx_en_i = 1;
        @(posedge clk6x);
        # 5;
        // tx_en_i = 0;
        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);

        /////////////////////////////////////////////////////
        spi_csn_i = 0;
        sending_byte = 8'h01;
        spi_mosi_i = sending_byte[7];
        # 161;

        for (j = 0; j < 8; ++j)
        begin
            // rising edge
            spi_clk_i = 1;
            # 81;
            // falling edge
            spi_clk_i = 0;

            sending_byte = { sending_byte[6:0], 1'b0 };
            spi_mosi_i = sending_byte[7];
            # 81;
        end


        sending_byte = 8'h20;
        spi_mosi_i = sending_byte[7];
        # 161;

        for (j = 0; j < 8; ++j)
        begin
            // rising edge
            spi_clk_i = 1;
            # 81;
            // falling edge
            spi_clk_i = 0;

            sending_byte = { sending_byte[6:0], 1'b0 };
            spi_mosi_i = sending_byte[7];
            # 81;
        end


        sending_byte = 8'h80;
        spi_mosi_i = sending_byte[7];
        # 161;

        for (j = 0; j < 8; ++j)
        begin
            // rising edge
            spi_clk_i = 1;
            # 81;
            // falling edge
            spi_clk_i = 0;

            sending_byte = { sending_byte[6:0], 1'b0 };
            spi_mosi_i = sending_byte[7];
            # 81;
        end


        sending_byte = 8'hA5;
        spi_mosi_i = sending_byte[7];
        # 161;

        for (j = 0; j < 8; ++j)
        begin
            // rising edge
            spi_clk_i = 1;
            # 81;
            // falling edge
            spi_clk_i = 0;

            sending_byte = { sending_byte[6:0], 1'b0 };
            spi_mosi_i = sending_byte[7];
            # 81;
        end


        sending_byte = 8'hC4;
        spi_mosi_i = sending_byte[7];
        # 161;

        for (j = 0; j < 8; ++j)
        begin
            // rising edge
            spi_clk_i = 1;
            # 81;
            // falling edge
            spi_clk_i = 0;

            sending_byte = { sending_byte[6:0], 1'b0 };
            spi_mosi_i = sending_byte[7];
            # 81;
        end

        # 161;
        spi_csn_i = 1;

        # 200;

        $finish;
    end

    ///////////////////////////////////////
    /// HANDLE BYTES RECEIVED BY SPI SLAVE

    reg [7:0] header_byte;
    reg [7:0] address_byte;
    reg [7:0] counter;
    reg [7:0] some_delay;

    always @(posedge clk6x)
    begin
        tx_en_i <= 0;

        if (rx_hdr_en_o)
        begin
            // first byte - command
            header_byte <= rx_byte_o;
            counter <= 0;
            tx_byte_i <= 0;
        end

        if (rx_db_en_o)
        begin
            if (counter == 0)
            begin
                // first data byte received
                address_byte <= rx_byte_o;
            end

            counter <= counter + 1;
            // some_delay <= 8'd10;
        // end else begin
        //     if (some_delay == 1)
        //     begin
        //         some_delay <= 0;
        //         tx_byte_i <= ~counter + address_byte;
                tx_byte_i <= header_byte + rx_byte_o;
                tx_en_i <= 1;
        //     end else begin
        //         some_delay <= some_delay - 1;
        //     end
        end
        
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);
    end
endmodule
