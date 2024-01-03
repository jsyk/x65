`timescale 1ns/100ps

module tb_uart_host ( );

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

    // Global signals
    reg           clk;                    // 48MHz
    reg           resetn;                 // sync reset

    // UART RX/TX signal to the FPGA pin
    wire            tx_pin_o;
    wire           rx_pin_i = tx_pin_o;
    wire            txde_o;              // tx drive enable, active high
    wire           cts_pin_i = 0;
    wire          rts_pin_o;
    //
    // REGISTER INTERFACE
    wire [7:0]    reg_d_o;            // read data output from the core (from the CONTROL or DATA REG)
    reg  [7:0]    reg_d_i;            // write data input to the core (to the CONTROL or DATA REG)
    reg           reg_wr_i;           // write signal
    reg           reg_rd_i;           // read signal
    reg           reg_cs_ctrl_i;           // target register select: CTRL REG
    reg           reg_cs_stat_i;            // target register select: STAT REG
    reg           reg_cs_data_i;            // target register select: DATA REG (FIFO)
    wire          irq_o;               // IRQ output, active high

    uart_host #(
        .RXFIFO_DEPTH_BITS (4),
        .TXFIFO_DEPTH_BITS (4)
    ) dut (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        //
        // UART INTERFACE
        // UART RX/TX signal to the FPGA pin
        .rx_pin_i (rx_pin_i),
        .tx_pin_o (tx_pin_o),
        .txde_o (txde_o),              // tx drive enable, active high
        .cts_pin_i (cts_pin_i),
        .rts_pin_o (rts_pin_o),
        //
        // REGISTER INTERFACE
        .reg_d_o (reg_d_o),            // read data output from the core (from the CONTROL or DATA REG)
        .reg_d_i (reg_d_i),            // write data input to the core (to the CONTROL or DATA REG)
        .reg_wr_i (reg_wr_i),           // write signal
        .reg_rd_i (reg_rd_i),           // read signal
        .reg_cs_ctrl_i (reg_cs_ctrl_i),           // target register select: CTRL REG
        .reg_cs_stat_i (reg_cs_stat_i),            // target register select: STAT REG
        .reg_cs_data_i (reg_cs_data_i),            // target register select: DATA REG (FIFO)
        .irq_o (irq_o)               // IRQ output, active high
    );

    // Clock Generator
    initial clk = 1'b0;
    always #(20)
    begin
        clk = ~clk;
    end

    initial 
    begin
        resetn <= 0;
        reg_d_i <= 0;
        reg_wr_i <= 0;
        reg_rd_i <= 0;
        reg_cs_ctrl_i <= 0;
        reg_cs_data_i <= 0;
        reg_cs_stat_i <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        resetn <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        // send char A5
        reg_d_i <= 8'ha5;
        reg_wr_i <= 1;
        reg_cs_data_i <= 1;
        @(posedge clk);
        reg_cs_data_i <= 0;

        @(posedge clk);
        @(posedge clk);

        // send char 5A
        reg_d_i <= 8'h5A;
        reg_cs_data_i <= 1;
        @(posedge clk);
        reg_wr_i <= 0;
        reg_cs_data_i <= 0;
        @(posedge clk);

        // wait on STAT reg, bit [2] tx fifo empty
        reg_rd_i <= 1;
        reg_cs_stat_i <= 1;
        @(posedge clk);
        while (!reg_d_o[2])
        begin
            @(posedge clk); // wait
        end
        reg_cs_stat_i <= 0;
        @(posedge clk);

        // wait on STAT reg, bit [0] rx fifo empty
        reg_rd_i <= 1;
        reg_cs_stat_i <= 1;
        @(posedge clk);
        while (reg_d_o[0])
        begin
            @(posedge clk); // wait
        end
        reg_cs_stat_i <= 0;
        @(posedge clk);

        // read from RX FIFO
        reg_rd_i <= 1;
        reg_cs_data_i <= 1;
        @(posedge clk);
        reg_cs_data_i <= 0;
        `assert(reg_d_o, 8'hA5);
        @(posedge clk);

        // wait on STAT reg, bit [0] rx fifo empty
        reg_rd_i <= 1;
        reg_cs_stat_i <= 1;
        @(posedge clk);
        while (reg_d_o[0])
        begin
            @(posedge clk); // wait
        end
        reg_cs_stat_i <= 0;
        @(posedge clk);

        // read from RX FIFO
        reg_rd_i <= 1;
        reg_cs_data_i <= 1;
        @(posedge clk);
        reg_cs_data_i <= 0;
        `assert(reg_d_o, 8'h5A);
        @(posedge clk);

        #20000;
        $finish;
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_uart_host.vcd");
        $dumpvars(0, tb_uart_host);
    end

endmodule