`timescale 1ns/100ps

module tb_spi_master ();

    localparam NUM_TARGETS = 1;

    // Global signals
    reg           clk;                    // 48MHz
    reg           resetn;                 // sync reset
    // Prescaler for the SPI clock freq
    reg [7:0]     prescaler;
    // SPI Master Peripheral signals
    wire      spi_clk;
    wire [NUM_TARGETS-1:0]   spi_csn;           // active low
    wire          spi_mosi;
    wire      spi_mosi_drive;
    reg           spi_miso;
    // Target addressing
    reg [NUM_TARGETS-1:0]   target_id;
    reg           target_en;         // bus enable -> generates csn signal to the target
    // Data to send to the SPI bus to the addressed target
    reg [7:0]     tx_byte;          // transmit data byte
    reg           tx_en;            // flag: catch the transmit byte
    wire          tx_ready;         // flag: it is possible to enqueue next tx byte now.
    // Received data from the SPI bus
    wire [7:0]    rx_byte;          // received byte data
    wire        rx_en;             // flag: received a byte


    spi_master dut (
        clk, resetn, prescaler,
        spi_clk, spi_csn, spi_mosi, spi_mosi_drive, spi_miso,
        target_id, target_en, 
        tx_byte, tx_en, tx_ready,
        rx_byte, rx_en
    );

    // Clock Generator
    initial clk = 1'b0;
    always #(20)
    begin
        clk = ~clk;
    end


    always @(spi_mosi)
    begin
        spi_miso = spi_mosi;
    end

    initial
    begin
        resetn <= 0;
        prescaler <= 1;
        spi_miso <= 0;
        target_id <= 0;
        target_en <= 0;
        tx_byte <= 0;
        tx_en <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        resetn <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        target_id[0] <= 1;
        target_en <= 1;
        @(posedge clk);
        @(posedge tx_ready);
        tx_byte <= 8'hA5;
        tx_en <= 1;
        @(posedge clk);
        tx_en <= 0;
        @(posedge tx_ready);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);


        $finish;
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule
