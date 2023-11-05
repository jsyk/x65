/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * Wrapper for YM2151-emulated FM / OPM sound core IKAOPM.
 * This is in case the OPM is INCLUDED insider NORA, which is depracted because it takes
 * a lot of resources. Recomended is IKAOPM in AURA FPGA.
 */
module fm2151 
(
    // Global signals
    input           clk,      // 48MHz
    input           resetn,     // sync reset
    // Host interface (slave)
    input [4:0]     slv_addr_i,
    input [7:0]     slv_datawr_i,     // write data = available just at the end of cycle!!
    input           slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    output [7:0]    slv_datard_o,       // read data
    input           slv_req_i,          // request (chip select)
    input           slv_rwn_i,           // read=1, write=0
    output          slv_irqn_o,         // interrupt output, active low
    // Sound output to the on-board DAC
    output          audio_bck,
    output          audio_data,
    output          audio_lrck
);

    // ym2151 cpu bus interface
    wire  cs_n = ~(slv_req_i & slv_datawr_valid);
    wire  wr_n = slv_rwn_i;
    wire  a0 = slv_addr_i[0];
    wire  [7:0] din = slv_datawr_i;

    // parallel output DAC data from the OPM
    wire signed  [15:0] left_chan;
    wire signed  [15:0] right_chan;

    // clk dividers for OPM
    reg     [4:0]   clkdiv = 4'b0000;
    wire            phiM_PCEN_n = ~(clkdiv == 4'd0);
    
    reg             phiMref = 1'b0;

    // Generate phiMref as clk div 14 ==> 48MHz / 14 = 3.43MHz.
    // This must run even during resetn, so that OPM is cleared well. 
    // It needs many reset cycles to flush pipelines!
    // Output sampling frequency will be 53.657 kHz
    always @(posedge clk) 
    begin
        if (clkdiv == 4'd13) 
        begin 
            clkdiv <= 4'b0000;
            phiMref <= 1'b1; 
        end else begin 
            clkdiv <= clkdiv + 4'b0001;
        end

        if (clkdiv == 4'd7) 
        begin
            phiMref <= 1'b0;
        end
    end


    //Verilog module instantiation example
    IKAOPM #(
        .FULLY_SYNCHRONOUS          (1                          ),
        .FAST_RESET                 (1                          ),
        .USE_BRAM                   (1                          )
    ) u_ikaopm_0 (
        .i_EMUCLK                   ( clk                          ),   // 48MHz

        .i_phiM_PCEN_n              ( phiM_PCEN_n                  ),     // nENABLE 

        .i_IC_n                     ( resetn                          ),

        .o_phi1                     (                           ),

        //.o_EMU_BUSY_FLAG            (                           ), //compilation option
        .i_CS_n                     (  cs_n                         ),
        .i_RD_n                     (  ~wr_n                         ),
        .i_WR_n                     (  wr_n                         ),
        .i_A0                       (  a0                         ),

        .i_D                        (  din                         ),
        // Reads are very easy, because YM2151 has just single read register: the STATUS with the Busy flag in MSB.
        // This register is always preset on the o_D from IKAOPM. We just always present it on.
        .o_D                        (  slv_datard_o              ),
        .o_D_OE                     (                           ),

        .o_CT1                      (                           ),
        .o_CT2                      (                           ),

        .o_IRQ_n                    ( slv_irqn_o                ),

        .o_SH1                      (                           ),
        .o_SH2                      (                           ),

        .o_SO                       (                           ),

        .o_EMU_R_SAMPLE             (                           ),
        .o_EMU_R_EX                 (                           ),
        .o_EMU_R                    (  right_chan               ),

        .o_EMU_L_SAMPLE             (                           ),
        .o_EMU_L_EX                 (                           ),
        .o_EMU_L                    (  left_chan                )
    );

    // assign slv_datard_o = 8'h00;            // HACK

    I2S_encoder #(
        .LRCLK_DIV (10'd982),
        .BCLK_DIV  (4'd15)
    ) enc (
        // Global signals
        .clk        (clk),              // system clock 48MHz
        .resetn     (resetn),           // system reset, low-active sync.
        // Input sound samples
        .r_chan_i   (right_chan),
        .l_chan_i   (left_chan),
        // Output I2S signal
        .lrclk_o    (audio_lrck),
        .bclk_o     (audio_bck),
        .dacdat_o   (audio_data)
    );


    always @(posedge clk) 
    begin
    end

endmodule
