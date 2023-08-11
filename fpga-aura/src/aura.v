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
    // Audio input from VERA
    input       VAUDIO_LRCK,
    input       VAUDIO_DATA,
    input       VAUDIO_BCK,
    // Audio output
    output reg      AUDIO_BCK,
    output reg     AUDIO_DATA,
    output reg      AUDIO_LRCK,
    // SPI Flash
    output      ASPI_MOSI,
    input       ASPI_MISO,
    output      ASPI_SCK,
    output      AFLASH_SSELN
);
    // IMPLEMENTATION

    // assign DB[0] = AB[0];

    wire clk = ASYSCLK;         // TBD correct frequency!!
    wire resetn = 1;            // TBD

    // clock-enables at 3.57Mhz and 1.78MHz
    wire cen_fm, cen_fm2;

    jtframe_cen3p57 u_cen (
        .clk        ( clk       ),       // 48 MHz
        .cen_3p57   ( cen_fm    ),
        .cen_1p78   ( cen_fm2   )
    );


    wire  cs_n = ACS1N;
    wire  wr_n = MWRN;
    wire  a0 = AB[0];
    wire  [7:0] din = DB;
    wire [7:0] dout;

    wire signed  [15:0] left, xleft;
    wire signed  [15:0] right, xright;
    wire                sample, ct1, ct2, irq_n;

    assign AIRQN = irq_n;

    jt51 uut(
        .rst        (  !resetn      ),    // reset, active high
        .clk        (  clk      ),    // main clock 48Mhz (or whatever)
        .cen        (  cen_fm   ),    // clock enable to gear down to 3.57 MHz, nominal for YM2151
        .cen_p1     (  cen_fm2  ), // clock enable at half the speed (1.78MHz)
        .cs_n       (  cs_n     ),   // chip select
        .wr_n       (  wr_n     ),   // write
        .a0         (  a0       ),
        .din        (  din      ), // data in
        .dout       (  dout     ), // data out
        // peripheral control
        .ct1        ( ct1       ),
        .ct2        ( ct2       ),
        .irq_n      ( irq_n     ),  // I do not synchronize this signal
        // Low resolution output (same as real chip)
        .sample     ( sample    ), // marks new output sample
        .left       ( left      ),
        .right      ( right     ),
        // Full resolution output
        .xleft      ( xleft     ),
        .xright     ( xright    )
    );


    always @(posedge clk)
    begin
        AUDIO_LRCK <= sample;
        AUDIO_BCK <= xleft[0];
        AUDIO_DATA <= xright[0];
    end


endmodule



module jtframe_cen3p57(
    input      clk,       // 48 MHz
    output reg cen_3p57,
    output reg cen_1p78
);

wire [10:0] step=11'd105;
wire [10:0] lim =11'd1408;
wire [10:0] absmax = lim+step;

reg  [10:0] cencnt=11'd0;
reg  [10:0] next;
reg  [10:0] next2;

always @(*) begin
    next  = cencnt+11'd105;
    next2 = next-lim;
end

reg alt=1'b0;

always @(posedge clk) begin
    cen_3p57 <= 1'b0;
    cen_1p78 <= 1'b0;
    if( cencnt >= absmax ) begin
        // something went wrong: restart
        cencnt <= 11'd0;
        alt    <= 1'b0;
    end else
    if( next >= lim ) begin
        cencnt <= next2;
        cen_3p57 <= 1'b1;
        alt    <= ~alt;
        if( alt ) cen_1p78 <= 1'b1;
    end else begin
        cencnt <= next;
    end
end
endmodule
