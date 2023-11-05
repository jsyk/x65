/**
 * TESTBENCH FOR IKAOPM with 48MHz system clock and I2S output.
 */
`timescale 1ns/100ps
module IKAOPM_48MHz_I2S_tb;

//BUS IO wires
reg             EMUCLK = 1'b1;
reg             IC_n = 1'b1;
reg             CS_n = 1'b1;
reg             WR_n = 1'b1;
reg             A0 = 1'b0;
reg     [7:0]   DIN = 8'h0;

reg             block_cen = 1'b0;

wire            phi1, sh1, sh2, sd;


//generate clock
// always #35 EMUCLK = ~EMUCLK;        // EMUCLK period = 70ns =  14.285714 Mhz
always #10.4 EMUCLK = ~EMUCLK;        // EMUCLK period = 20.8ns =  48.07 MHz (target is 48Mhz)

reg     [4:0]   clkdiv = 4'b0000;
reg             phiMref = 1'b0;

// phiM n_enable as EMUCLK div 4 (they internaly divide by 2)
// wire            phiM_PCEN_n = ~(clkdiv == 3'd0 || clkdiv == 3'd4) | block_cen;
// phiM n_enable as EMUCLK div 7 (they internaly divide by 2)
// wire            phiM_PCEN_n = ~(clkdiv == 4'd0 || clkdiv == 4'd7) | block_cen;
// phiM n_enable as EMUCLK div 14
wire            phiM_PCEN_n = ~(clkdiv == 4'd0) | block_cen;

// generate phiMref as EMUCLK div 14 ==> 48MHz / 14 = 3.43MHz
// Output sampling frequency will be 53.657 kHz
always @(posedge EMUCLK) begin
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


//async reset
initial begin
    #(30*35) IC_n <= 1'b0;
    #(1300*35) IC_n <= 1'b1;
end

wire            emu_r_sample, emu_l_sample;
wire signed     [15:0]  emu_r_ex, emu_l_ex;
wire signed     [15:0]  emu_r, emu_l;


//main chip
IKAOPM #(
    .FULLY_SYNCHRONOUS          (1                          ),
    .FAST_RESET                 (1                          )
) main (
    // phyM required 3.58MHz.
    // EMUCLK will be divided by i_phiM_PCEN_n*2 to get the phyM.
    // Therefore i_phiM_PCEN_n division = freq(EMUCLK) / 3.58MHz / 2 = 48e6 / 3.58e6 / 2 = 6.704 x
    .i_EMUCLK                   (EMUCLK                     ),

    .i_phiM_PCEN_n              (phiM_PCEN_n),
    // .i_phi1_PCEN_n              (~(clkdiv == 3'd0) | block_cen),
    // .i_phi1_NCEN_n              (~(clkdiv == 3'd4) | block_cen),


    .i_IC_n                     (IC_n                       ),

    // phi1 should be 1/2 of phiM, typically 1.7MHz (we have 1.717Mhz)
    .o_phi1                     (phi1                       ),

    .i_CS_n                     (CS_n                       ),
    .i_RD_n                     (1'b1                       ),
    .i_WR_n                     (WR_n                       ),
    .i_A0                       (A0                         ),

    .i_D                        (DIN                        ),
    .o_D                        (                           ),
    .o_D_OE                     (                           ),

    .o_CT1                      (                           ),
    .o_CT2                      (                           ),

    .o_IRQ_n                    (                           ),

    .o_SH1                      (sh1                        ),
    .o_SH2                      (sh2                        ),

    .o_SO                       (sd                         ),

    .o_EMU_R_SAMPLE             (emu_r_sample               ),      // 53.657 kHz
    .o_EMU_L_SAMPLE             (emu_l_sample               ),      // 53.657 kHz
    .o_EMU_R_EX                 (emu_r_ex                   ),
    .o_EMU_L_EX                 (emu_l_ex                   ),
    .o_EMU_R                    (emu_r                      ),
    .o_EMU_L                    (emu_l                      )
);

YM3012 u_dac (
    .i_phi1                     (phi1                       ),
    .i_SH1                      (sh1                        ),
    .i_SH2                      (sh2                        ),
    .i_DI                       (sd                         ),
    .o_R                        (                           ),
    .o_L                        (                           )
);


// Output I2S signal
wire              i2s_lrclk_o;
wire              i2s_bclk_o;
wire              i2s_dacdat_o;


I2S_encoder #(
    .LRCLK_DIV (10'd982),
    .BCLK_DIV  (4'd15)
) enc (
    // Global signals
    .clk        (EMUCLK),              // system clock 48MHz
    .resetn     (IC_n),           // system reset, low-active sync.
    // Input sound samples
    .r_chan_i   (emu_r_ex),
    .l_chan_i   (emu_l_ex),
    // Output I2S signal
    .lrclk_o    (i2s_lrclk_o),
    .bclk_o     (i2s_bclk_o),
    .dacdat_o   (i2s_dacdat_o)
);



task automatic IKAOPM_write (
    input       [7:0]   i_TARGET_ADDR,
    input       [7:0]   i_WRITE_DATA
); begin
    #0   CS_n = 1'b0; WR_n = 1'b1; A0 = 1'b0; DIN = i_TARGET_ADDR;
    #(30*35)  CS_n = 1'b0; WR_n = 1'b0; A0 = 1'b0; DIN = i_TARGET_ADDR;
    #(40*35)  CS_n = 1'b1; WR_n = 1'b1; A0 = 1'b0; DIN = i_TARGET_ADDR;
    #(30*35)  CS_n = 1'b0; WR_n = 1'b1; A0 = 1'b1; DIN = i_WRITE_DATA;
    #(30*35)  CS_n = 1'b0; WR_n = 1'b0; A0 = 1'b1; DIN = i_WRITE_DATA;
    #(40*35)  CS_n = 1'b1; WR_n = 1'b1; A0 = 1'b1; DIN = i_WRITE_DATA;
end endtask

initial begin
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

    initial
    begin
        // time in 1ns-units
        // # 100_000_000;      // 100ms
        # 10_000_000;      // 10ms
        // # 10000000_00;
        $finish;
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("IKAOPM_48MHz_I2S_tb.vcd");
        $dumpvars(0,IKAOPM_48MHz_I2S_tb);
    end


endmodule


// ////////////////////////////////////////////////////////////////////////////////

module I2S_encoder #(
    parameter LRCLK_DIV = 10'd982,
    parameter BCLK_DIV = 4'd15
) (
    // Global signals
    input   clk,              // system clock 48MHz
    input   resetn,           // system reset, low-active sync.
    // Input sound samples
    input wire [15:0]       r_chan_i,
    input wire [15:0]       l_chan_i,
    // Output I2S signal
    output reg              lrclk_o,
    output reg              bclk_o,
    output reg              dacdat_o
);
    // IMPLEMENTATION

    // pre-divider for lrclk generation
    reg [9:0]  prediv_lrclk_r;

    // pre-divider for bclk generation
    reg [3:0]  prediv_bclk_r;

    // output shift register for the 16-bit data, MSB-first
    reg [15:0] shifter;

    // generate all output signals
    always @(posedge clk) 
    begin
        if (!resetn)
        begin
            prediv_lrclk_r <= 0;
            lrclk_o <= 0;
            prediv_bclk_r <= 0;
            bclk_o <= 0;
            shifter <= 0;
            dacdat_o <= 0;
        end else begin

            // BCLK generator: reached top?
            if (prediv_bclk_r == BCLK_DIV)
            begin
                // yes -> reset to 0 and falling edge
                prediv_bclk_r <= 0;
                bclk_o <= 0;
                // set output data, MSB-first
                dacdat_o <= shifter[15];
                shifter <= { shifter[14:0], 1'b0 };     // shift left, insert 0 to LSB.
            end else begin
                // no -> count
                prediv_bclk_r <= prediv_bclk_r + 1;
            end

            // BCLK in the middle?
            if (prediv_bclk_r == BCLK_DIV/2)
            begin
                // yes -> rising edge
                bclk_o <= 1;
            end


            // LRCLK: reached top?
            if (prediv_lrclk_r == LRCLK_DIV)
            begin
                // yes -> reset to 0
                prediv_lrclk_r <= 0;
                // output to 0 (falling edge on LRCLK)
                lrclk_o <= 0;
                // I2S will output LEFT channel now
                shifter <= l_chan_i;
                // reset BCLK (maybe falling edge)
                bclk_o <= 0;
                prediv_bclk_r <= 0;
            end else begin
                // no -> count
                prediv_lrclk_r <= prediv_lrclk_r + 1;
            end

            // LRCLK: in the middle?
            if (prediv_lrclk_r == LRCLK_DIV/2)
            begin
                // yes -> rising edge
                // output to 1
                lrclk_o <= 1;
                // I2S will output RIGHT channel now
                shifter <= r_chan_i;
                // reset BCLK
                bclk_o <= 0;
                prediv_bclk_r <= 0;
            end

        end
    end

endmodule

// ////////////////////////////////////////////////////////////////////////////////


module YM3012 (
    input   wire                i_phi1,
    input   wire                i_SH1, //right
    input   wire                i_SH2, //left
    input   wire                i_DI,
    output  wire signed [15:0]  o_R,
    output  wire signed [15:0]  o_L
);

reg             sh1_z, sh1_zz, sh2_z, sh2_zz;
always @(posedge i_phi1) begin
    sh1_z <= i_SH1;
    sh2_z <= i_SH2;
end
always @(posedge i_phi1) begin
    sh1_zz <= sh1_z;
    sh2_zz <= sh2_z;
end

wire            right_ld = ~(sh1_z | ~sh1_zz);
wire            left_ld = ~(sh2_z | ~sh2_zz);

reg     [13:0]  right_sr, left_sr;
always @(posedge i_phi1) begin
    right_sr[13] <= i_DI;
    right_sr[12:0] <= right_sr[13:1];

    left_sr[13] <= i_DI;
    left_sr[12:0] <= left_sr[13:1];
end

reg     [12:0]  right_latch, left_latch;
// always @(*) begin
//     if(right_ld) right_latch = right_sr[12:0];
//     if(left_ld) left_latch = left_sr[12:0];
// end

always @(posedge i_phi1) begin
    if (right_ld) right_latch <= right_sr[12:0];
    if (left_ld) left_latch <= left_sr[12:0];
end

reg signed  [15:0]  right_output, left_output;
always @(*) begin
    case(right_latch[12:10])
        3'd0: right_output = 16'dx;
        3'd1: right_output = right_latch[9] ? {1'b0, 6'b000000, right_latch[8:0]     } : ~{1'b0, 6'b000000, ~right_latch[8:0]     } + 16'd1;
        3'd2: right_output = right_latch[9] ? {1'b0, 5'b00000, right_latch[8:0], 1'b0} : ~{1'b0, 5'b00000, ~right_latch[8:0], 1'b0} + 16'd1;
        3'd3: right_output = right_latch[9] ? {1'b0, 4'b0000, right_latch[8:0], 2'b00} : ~{1'b0, 4'b0000, ~right_latch[8:0], 2'b00} + 16'd1;
        3'd4: right_output = right_latch[9] ? {1'b0, 3'b000, right_latch[8:0], 3'b000} : ~{1'b0, 3'b000, ~right_latch[8:0], 3'b000} + 16'd1;
        3'd5: right_output = right_latch[9] ? {1'b0, 2'b00, right_latch[8:0], 4'b0000} : ~{1'b0, 2'b00, ~right_latch[8:0], 4'b0000} + 16'd1;
        3'd6: right_output = right_latch[9] ? {1'b0, 1'b0, right_latch[8:0], 5'b00000} : ~{1'b0, 1'b0, ~right_latch[8:0], 5'b00000} + 16'd1;
        3'd7: right_output = right_latch[9] ? {1'b0,      right_latch[8:0], 6'b000000} : ~{1'b0,      ~right_latch[8:0], 6'b000000} + 16'd1;
    endcase
end


endmodule