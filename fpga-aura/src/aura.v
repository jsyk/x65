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


    wire clk = ASYSCLK;

    /**
    * Autonomous reset generator
    */
    resetgen rstgen0 (
        .clk (clk), .clklocked (1'b1), .rstreq(1'b0),
        .resetn (resetn)
    );


    wire  cs_n = ACS1N;
    wire  wr_n = MWRN;
    wire  a0 = AB[0];
    wire  [7:0] din = DB;
    wire [7:0] dout;
    wire  dout_en;

    assign AIRQN = irq_n;

    // parallel output DAC data from the OPM
    wire signed  [15:0] left_chan;
    wire signed  [15:0] right_chan;

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


    //Verilog module instantiation example
    IKAOPM #(
        .FULLY_SYNCHRONOUS          (1                          ),
        .FAST_RESET                 (1                          )
    ) u_ikaopm_0 (
        .i_EMUCLK                   ( clk                          ),   // 25MHz

        .i_phiM_PCEN_n              ( phiM_PCEN_n                  ),     // nENABLE 

        .i_IC_n                     ( resetn                          ),

        .o_phi1                     (                           ),

        //.o_EMU_BUSY_FLAG            (                           ), //compilation option
        .i_CS_n                     (  cs_n                         ),
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
        .o_EMU_R_EX                 (  right_chan               ),
        .o_EMU_R                    (                           ),

        .o_EMU_L_SAMPLE             (                           ),
        .o_EMU_L_EX                 (  left_chan                ),
        .o_EMU_L                    (                           )
    );

    assign DB = (dout_en) ? dout : 8'hZZ;

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


    assign IOCSN = 1'b1;            // TBD
    
    assign ASPI_MOSI = 1'bZ;
    assign ASPI_SCK = 1'b1;
    assign AFLASH_SSELN = 1'b1;

endmodule

