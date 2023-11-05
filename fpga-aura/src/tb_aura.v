/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/* TESTBENCH FOR AURA-FPGA */
`timescale 1ns/100ps
module tb_aura;

    // System Clock input
    reg       ASYSCLK = 0;        // 25MHz
    // I/O Bus
    reg [4:0]  AB;
    wire [7:0]  DB;
    reg       ACS1N;          // primary chip-select for audio functions
    reg       VCS0N;          // VERA chipselect, possible snooping
    reg       MRDN;           // read cmd
    reg       MWRN;           // write cmd
    wire      AIRQN;          // IRQ output
    wire      IOCSN;          // IO CSn output
    // Audio input from VERA
    wire       VAUDIO_LRCK;
    wire       VAUDIO_DATA;
    wire       VAUDIO_BCK;
    // Audio output
    wire       AUDIO_BCK;
    wire      AUDIO_DATA;
    wire       AUDIO_LRCK;
    // SPI Flash
    wire      ASPI_MOSI;
    reg       ASPI_MISO = 1'b1;
    wire      ASPI_SCK;
    wire      AFLASH_SSELN;

    // our DB driver
    reg DBt;
    reg [7:0] DBq;


    //generate clock
    always #20 ASYSCLK = ~ASYSCLK;        // ASYSCLK period = 40ns =  25 MHz


    aura dut
    (
        // System Clock input
        .ASYSCLK        (ASYSCLK),        // 25MHz
        // I/O Bus
        .AB             (AB),
        .DB             (DB),
        .ACS1N          (ACS1N),          // primary chip-select for audio functions
        .VCS0N          (VCS0N),          // VERA chipselect, possible snooping
        .MRDN           (MRDN),           // read cmd
        .MWRN           (MWRN),           // write cmd
        .AIRQN          (AIRQN),          // IRQ output
        .IOCSN          (IOCSN),          // IO CSn output
        // Audio input from VERA
        .VAUDIO_LRCK    (VAUDIO_LRCK),
        .VAUDIO_DATA    (VAUDIO_DATA),
        .VAUDIO_BCK     (VAUDIO_BCK),
        // Audio output
        .AUDIO_BCK      (AUDIO_BCK),
        .AUDIO_DATA     (AUDIO_DATA),
        .AUDIO_LRCK     (AUDIO_LRCK),
        // SPI Flash
        .ASPI_MOSI      (ASPI_MOSI),
        .ASPI_MISO      (ASPI_MISO),
        .ASPI_SCK       (ASPI_SCK),
        .AFLASH_SSELN   (AFLASH_SSELN)
    );


    assign DB = (DBt == 1'b1) ? DBq : 8'hZZ;

    // ------------------------------------------------------

    task automatic IKAOPM_write (
        input       [7:0]   i_TARGET_ADDR,
        input       [7:0]   i_WRITE_DATA
    ); begin
        #0   ACS1N = 1'b0; MWRN = 1'b1; AB[0] = 1'b0; DBq = i_TARGET_ADDR; DBt = 1'b1;
        #(30*35)  ACS1N = 1'b0; MWRN = 1'b0; AB[0] = 1'b0; DBq = i_TARGET_ADDR;
        #(40*35)  ACS1N = 1'b1; MWRN = 1'b1; AB[0] = 1'b0; DBq = i_TARGET_ADDR;
        #(30*35)  ACS1N = 1'b0; MWRN = 1'b1; AB[0] = 1'b1; DBq = i_WRITE_DATA;
        #(30*35)  ACS1N = 1'b0; MWRN = 1'b0; AB[0] = 1'b1; DBq = i_WRITE_DATA;
        #(40*35)  ACS1N = 1'b1; MWRN = 1'b1; AB[0] = 1'b1; DBq = i_WRITE_DATA;
        #(30*35)  ACS1N = 1'b1; MWRN = 1'b1; AB[0] = 1'b1; DBq = i_WRITE_DATA; DBt = 1'b0;
    end endtask

    initial begin
        AB = 5'h00;
        DBt = 1'b0;
        DBq = 8'h00;
        ACS1N = 1'b1;
        VCS0N = 1'b1;
        MRDN = 1'b1;
        MWRN = 1'b1;

        // wait 4 us for IKAOPM to complete the reset
        #(2100*35);

        //KC
        #(600*35) IKAOPM_write(8'h28, {4'h4, 4'h2}); //ch1

        //MUL
        #(600*35) IKAOPM_write(8'h40, {1'b0, 3'd0, 4'd2}); 
        #(600*35) IKAOPM_write(8'h50, {1'b0, 3'd0, 4'd1});

        //TL
        #(600*35) IKAOPM_write(8'h60, {8'd21});
        #(600*35) IKAOPM_write(8'h70, {8'd1});
        #(600*35) IKAOPM_write(8'h68, {8'd127});
        #(600*35) IKAOPM_write(8'h78, {8'd127});

        //AR
        #(600*35) IKAOPM_write(8'h80, {2'd0, 1'b0, 5'd31}); 
        #(600*35) IKAOPM_write(8'h90, {2'd0, 1'b0, 5'd30});

        //AMEN/D1R(DR)
        #(600*35) IKAOPM_write(8'hA0, {1'b0, 2'b00, 5'd5});
        #(600*35) IKAOPM_write(8'hB0, {1'b0, 2'b00, 5'd18});

        //D2R(SR)
        #(600*35) IKAOPM_write(8'hC0, {2'd0, 1'b0, 5'd0});
        #(600*35) IKAOPM_write(8'hD0, {2'd0, 1'b0, 5'd7});

        //D1L(SL)RR
        #(600*35) IKAOPM_write(8'hE0, {4'd0, 4'd0});
        #(600*35) IKAOPM_write(8'hF0, {4'd1, 4'd4});

        //RL/FL/ALG
        #(600*35) IKAOPM_write(8'h20, {2'b11, 3'd7, 3'd4});

        //KON
        #(600*35) IKAOPM_write(8'h08, {1'b0, 4'b0011, 3'd0}); //write 0x7F, 0x08(KON)=
    end
    // ------------------------------------------------------

    reg [15:0] right_chan_stream = 16'h0012;
    reg [15:0] left_chan_stream = 16'h0034;
    reg enc_resetn;

    // encode output audio data into I2S
    I2S_encoder #(
        .LRCLK_DIV (10'd511),           // LRCLK = 25 Mhz / 512 = 48.828 kHz
        .BCLK_DIV  (4'd3)               // BCLK = 25 MHz / 4 = 6.25 Mhz
    ) enc (
        // Global signals
        .clk        (ASYSCLK),              // system clock 25 MHz
        .resetn     (enc_resetn),               // system reset, low-active sync.
        // Input sound samples
        .r_chan_i   (right_chan_stream),
        .l_chan_i   (left_chan_stream),
        // Output I2S signal
        .lrclk_o    (VAUDIO_LRCK),
        .bclk_o     (VAUDIO_BCK),
        .dacdat_o   (VAUDIO_DATA)
    );

    initial
    begin
        // reset encoder
        enc_resetn <= 0;
        # 200_000;
        enc_resetn <= 1;

        // let encoder run
        # 800_000;      // 800us

        // stop (reset) the encoder
        enc_resetn <= 0;
    end

    // ------------------------------------------------------
    initial
    begin
        // time in 1ns-units
        # 1_200_000;      // 10.2ms
        // # 10000000_00;
        $finish;
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_aura.vcd");
        $dumpvars(0,tb_aura);
    end



endmodule
