`timescale 1ns/100ps

module tb_fifo ( );

    parameter BITWIDTH = 8;          // bit-width of one data element
    parameter BITDEPTH = 2;          // fifo keeps 2**BITDEPTH elements

    // Global signals
    reg           clk6x;      // 48MHz
    reg           resetn;     // sync reset
    // I/O Write port
    reg [BITWIDTH-1:0]  wport_i;          // Write Port Data
    reg           wenq_i;                 // Enqueue data from the write port now; must not assert when full_o=1
    // I/O read port
    wire [BITWIDTH-1:0] rport_o;          // Read port data: valid any time empty_o=0
    reg           rdeq_i;                 // Dequeue current data from FIFO
    // Status signals
    wire      full_o;                 // FIFO is full?
    wire      empty_o;                 // FIFO is empty?


    fifo #(
        .BITWIDTH (BITWIDTH),          // bit-width of one data element
        .BITDEPTH (BITDEPTH)          // fifo keeps 2**BITDEPTH elements
    ) dut
    (
        // Global signals
        clk6x,      // 48MHz
        resetn,     // sync reset
        // I/O Write port
        wport_i,          // Write Port Data
        wenq_i,                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        rport_o,          // Read port data: valid any time empty_o=0
        rdeq_i,                 // Dequeue current data from FIFO
        // Status signals
        full_o,                 // FIFO is full?
        empty_o                 // FIFO is empty?
    );

    // Clock Generator
    initial clk6x = 1'b0;
    always #(20)
    begin
        clk6x = ~clk6x;
    end

    integer j;


    initial
    begin
        resetn = 1'b0;
        wport_i = 8'h00;
        wenq_i = 0;
        rdeq_i = 0;
        for (j = 0; j < 4; ++j)
        begin
            @(posedge clk6x);
        end

        resetn = 1'b1;
        for (j = 0; j < 4; ++j)
        begin
            @(posedge clk6x);
        end

        // enqueue some data
        wport_i <= 8'h12;
        wenq_i <= 1;
        @(posedge clk6x);
        wport_i <= 8'h34;
        @(posedge clk6x);
        wport_i <= 8'h56;
        @(posedge clk6x);
        wport_i <= 8'h78;
        @(posedge clk6x);
        wenq_i <= 0;
        @(posedge clk6x);

        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);

        // deqeue the data
        rdeq_i <= 1;
        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);
        rdeq_i <= 0;

        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);

        // enquee & dequeue data at the same time / fifo not full
        wport_i <= 8'h12;
        wenq_i <= 1;
        @(posedge clk6x);
        wport_i <= 8'h34;
        @(posedge clk6x);
        wport_i <= 8'h56;
        rdeq_i <= 1;
        @(posedge clk6x);
        wport_i <= 8'h78;
        @(posedge clk6x);
        wport_i <= 8'h9A;
        @(posedge clk6x);
        wport_i <= 8'hBC;
        @(posedge clk6x);
        wport_i <= 8'hDE;
        @(posedge clk6x);
        wenq_i <= 0;
        @(posedge clk6x);
        @(posedge clk6x);
        rdeq_i <= 0;


        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);

        // enquee & dequeue data at the same time
        wport_i <= 8'h12;
        wenq_i <= 1;
        @(posedge clk6x);
        wport_i <= 8'h34;
        @(posedge clk6x);
        wport_i <= 8'h56;
        @(posedge clk6x);
        wport_i <= 8'h78;
        @(posedge clk6x);
        wport_i <= 8'h9A;
        rdeq_i <= 1;
        @(posedge clk6x);
        wport_i <= 8'hBC;
        @(posedge clk6x);
        wport_i <= 8'hDE;
        @(posedge clk6x);
        wenq_i <= 0;
        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);
        @(posedge clk6x);
        rdeq_i <= 0;


        #1000;
        $finish;
    end


    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_fifo.vcd");
        $dumpvars(0,tb_fifo);
    end

endmodule