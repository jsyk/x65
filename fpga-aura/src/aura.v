/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/* AURA FPGA - YM2151 emulation.
 * Top-level code */
module aura
(
    // System Clock input
    input       ASYSCLK,        // 25MHz
    // I/O Bus
    input [4:0]  AB,
    inout [7:0]  DB,
    input       ACS1N,          // primary chip-select for audio functions
    input       VCS0N,          // VERA chipselect, possible snooping
    input       MRDN,           // read cmd
    input       MWRN,           // write cmd
    output      AIRQN,          // IRQ output
    output      IOCSN,          // IO CSn output
    // Audio input from VERA, I2S
    input       VAUDIO_LRCK,
    input       VAUDIO_DATA,
    input       VAUDIO_BCK,
    // Audio output I2S
    output       AUDIO_BCK,
    output       AUDIO_DATA,
    output       AUDIO_LRCK,
    // SPI Flash
    output      ASPI_MOSI,
    input       ASPI_MISO,
    output      ASPI_SCK,
    output      AFLASH_SSELN
);
    // IMPLEMENTATION

    // system clock 25MHz and main reset (active low)
    wire clk = ASYSCLK;
    reg  resetn = 1'b0;

    /**
    * reset generator
    */
    reg [7:0] rstcounter = 8'd0;

    // reset counter
    always @(posedge clk)
    begin
        // count up...
        if (rstcounter[7] != 1'b1)
        begin
            // counting
            rstcounter <= rstcounter + 4'd1;
            // keep reset active
            resetn <= 1'b0;
        end else begin
            // stop counting and release the reset
            resetn <= 1'b1;
        end
    end


    /* OPM CSN gets activated in the address range 0x9F40 - 0x9F43 */
    wire  opm_cs_n = ACS1N| AB[3] | AB[2];
    wire  wr_n = MWRN;
    wire  a0 = AB[0];
    wire  [7:0] din = DB;
    wire [7:0] dout;
    wire  dout_en;

    assign AIRQN = irq_n;

    // parallel output DAC data from the OPM
    wire signed  [15:0] opm_left_chan;
    wire signed  [15:0] opm_right_chan;

    // clk dividers for OPM
    reg     [4:0]   clkdiv = 4'b0000;
    wire            phiM_PCEN_n = ~(clkdiv == 4'd0);
    
    reg             phiMref = 1'b0;

    // Generate phiMref as clk div 7 ==> 25MHz / 7 = 3.57 MHz.
    // This must run even during resetn, so that OPM is cleared well. 
    // It needs many reset cycles to flush pipelines!
    // Output sampling frequency will be 53.657 kHz
    always @(posedge clk) 
    begin
        if (clkdiv == 4'd6) 
        begin 
            clkdiv <= 4'b0000;
            phiMref <= 1'b1; 
        end else begin 
            clkdiv <= clkdiv + 4'b0001;
        end

        if (clkdiv == 4'd3) 
        begin
            phiMref <= 1'b0;
        end
    end


    // YM2151 emulation
    IKAOPM #(
        .FULLY_SYNCHRONOUS          (1                          ),
        .FAST_RESET                 (1                          ),
        .USE_BRAM                   (1                          )
    ) u_ikaopm_0 (
        .i_EMUCLK                   ( clk                          ),   // 25MHz

        .i_phiM_PCEN_n              ( phiM_PCEN_n                  ),     // nENABLE 

        .i_IC_n                     ( resetn                          ),

        .o_phi1                     (                           ),

        //.o_EMU_BUSY_FLAG            (                           ), //compilation option
        .i_CS_n                     (  opm_cs_n                         ),
        .i_RD_n                     (  MRDN                         ),
        .i_WR_n                     (  MWRN                         ),
        .i_A0                       (  a0                         ),

        .i_D                        (  din                         ),
        // Reads are very easy, because YM2151 has just single read register: the STATUS with the Busy flag in MSB.
        // This register is always present on the o_D from IKAOPM. We just always present it on.
        .o_D                        (  dout                     ),
        .o_D_OE                     (  dout_en                  ),

        .o_CT1                      (                           ),
        .o_CT2                      (                           ),

        .o_IRQ_n                    ( irq_n                     ),

        .o_SH1                      (                           ),
        .o_SH2                      (                           ),

        .o_SO                       (                           ),

        .o_EMU_R_SAMPLE             (                           ),
        .o_EMU_R_EX                 (                           ),
        .o_EMU_R                    (  opm_right_chan           ),

        .o_EMU_L_SAMPLE             (                           ),
        .o_EMU_L_EX                 (                           ),
        .o_EMU_L                    (  opm_left_chan            )
    );

    assign DB = (dout_en) ? dout : 8'hZZ;

    // parallel output DAC data from the OPM
    wire signed  [15:0] va_left_chan;
    wire signed  [15:0] va_right_chan;

    // decode input audio from I2S from VERA
    I2S_decoder dec
    (
        // Global signals
        .clk            (clk),              // system clock 48MHz
        .resetn         (resetn),           // system reset, low-active sync.
        // Input I2S signal
        .lrclk_i        (VAUDIO_LRCK),
        .bclk_i         (VAUDIO_BCK),
        .dacdat_i       (VAUDIO_DATA),
        // Output sound samples
        .r_chan_o       (va_right_chan),           // right channel sample data
        .r_strobe_o     ( ),         // right channel strobe (sample update)
        .l_chan_o       (va_left_chan),           // left channel sample data
        .l_strobe_o     ( )          // left channel strobe (sample update)
    );

    // parallel output DAC data from the OPM and VERA
    reg signed  [15:0] left_chan;
    reg signed  [15:0] right_chan;

    // output mixing = 1/2 from each channel VERA and OPM
    always @(posedge clk) 
    begin
        left_chan <= (va_left_chan >>> 1) + (opm_left_chan >>> 1);
        right_chan <= (va_right_chan >>> 1) + (opm_right_chan >>> 1);
    end

    // encode output audio data into I2S
    I2S_encoder #(
        .LRCLK_DIV (10'd511),           // LRCLK = 25 Mhz / 512 = 48.828 kHz
        .BCLK_DIV  (4'd3)               // BCLK = 25 MHz / 4 = 6.25 Mhz
    ) enc (
        // Global signals
        .clk        (clk),              // system clock 25 MHz
        .resetn     (resetn),           // system reset, low-active sync.
        // Input sound samples
        .r_chan_i   (right_chan),
        .l_chan_i   (left_chan),
        // Output I2S signal
        .lrclk_o    (AUDIO_LRCK),
        .bclk_o     (AUDIO_BCK),
        .dacdat_o   (AUDIO_DATA)
    );



    // assign AUDIO_BCK = opm_right_chan[5];
    // assign AUDIO_DATA = opm_left_chan[7];
    // assign AUDIO_LRCK = opm_right_chan[9];

    /* IOCSN gets activated in the address range 0x9F4C - 0x9F4F */
    assign IOCSN = ACS1N | ~AB[3] | ~AB[2];
    
    assign ASPI_MOSI = 1'bZ;
    assign ASPI_SCK = 1'b1;
    assign AFLASH_SSELN = 1'b1;

endmodule

