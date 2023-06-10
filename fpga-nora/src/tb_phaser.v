// `include "phaser.v"
`timescale 1ns/100ps

module tb_phaser ();

    reg   clk6x;          // system clock, 6x faster than the 65C02 clock -> NORA has 6 microcycles (@48MHz) per one CPU cycle (@8MHz)
    reg   rstn;           // system reset, low-active sync.
    reg   run;
    wire  stopped;
    wire  cphi2;      // generated 65C02 PHI2 clock
    wire  vphi2;      // generated 65C22 PHI2 clock, which is shifted by +60deg (21ns)
    wire  setup_cs;   // catch CPU address and setup the CSx signals
    wire  release_cs;  // CPU access is complete, release the CS

    phaser ph0 ( 
        .clk  (clk6x),
        .resetn   (rstn),
        .run    (run),
        .stopped (stopped),
        .cphi2  (cphi2),
        .vphi2  (vphi2),
        .setup_cs (setup_cs),
        .release_cs (release_cs)
    );


    initial clk6x = 1'b0;

    always #(20)
    begin
        clk6x = ~clk6x;
    end

    integer j;

    initial
    begin
        rstn = 1'b0;
        run = 1'b0;
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end

        rstn = 1'b1;
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end

        run = 1'b1;
        for (j = 0; j < 50; ++j)
        begin
            @(posedge clk6x);
        end

        run = 1'b0;
        for (j = 0; j < 50; ++j)
        begin
            @(posedge clk6x);
        end

        run = 1'b1;
        for (j = 0; j < 50; ++j)
        begin
            @(posedge clk6x);
        end

        $finish;
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_phaser.vcd");
        $dumpvars(0,tb_phaser);
    end

endmodule
