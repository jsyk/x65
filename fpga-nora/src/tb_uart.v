`timescale 1ns/100ps

module tb_uart ();

    // Global signals
    reg           clk;                    // 48MHz
    reg           resetn;                 // sync reset
    // Prescaled tx-clock
    wire           uart_cken_i;              // 16x the UART transmit baud-rate, 1T pulses
    // Parity configuration
    reg           parity_type_i;          // which type of parity bit to transmit: 0=even, 1=odd.
    reg           parity_en_i;            // enable the generation of parity bit (1), or no parity (0)
    // Data to send to the TXD
    reg [7:0]     tx_byte_i;          // transmit data byte
    reg           tx_en_i;            // flag: catch the transmit byte
    wire          tx_ready_o;         // flag: it is possible to enqueue next tx byte now.
    // Output TX signal to the FPGA pin
    wire      tx_pin_o;
    wire        txde_o;

    reg [3:0]     prescaler_r;

    uart_tx txdut
    (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        // Prescaled tx-clock
        .uart_cken_i (uart_cken_i),              // 8x the UART transmit baud-rate, 1T pulses
        // Parity configuration
        .parity_type_i (parity_type_i),          // which type of parity bit to transmit: 0=even, 1=odd.
        .parity_en_i (parity_en_i),            // enable the generation of parity bit (1), or no parity (0)
        // Data to send to the TXD
        .tx_byte_i (tx_byte_i),          // transmit data byte
        .tx_en_i (tx_en_i),            // flag: catch the transmit byte
        .tx_ready_o (tx_ready_o),         // flag: it is possible to enqueue next tx byte now.
        // Output TX signal to the FPGA pin
        .tx_pin_o (tx_pin_o),
        .txde_o (txde_o)
    );

    wire [7:0] rx_byte_o;          // received data byte
    wire      rx_en_o;            // flag: got byte
    wire      frame_err_o;        // 1T flag indicates framing error (hi start bit or low stop bit)
    wire      parity_err_o;       // 1T flag indicates parity error (if parity is enabled)

    uart_rx rxdut
    (
        // Global signals
        .clk (clk),                    // 48MHz
        .resetn (resetn),                 // sync reset
        // Prescaled rx-clock
        .uart_cken_i (uart_cken_i),              // 16x the UART transmit baud-rate, 1T pulses
        // Parity configuration. Should be held constant normally, and changed just in idle.
        .parity_type_i (parity_type_i),          // which type of parity bit to expect: 0=even, 1=odd.
        .parity_en_i (parity_en_i),            // enable the receive of parity bit (1), or no parity (0)
        // Data received
        .rx_byte_o (rx_byte_o),          // received data byte
        .rx_en_o (rx_en_o),            // flag: got byte
        .frame_err_o (frame_err_o),        // 1T flag indicates framing error (hi start bit or low stop bit)
        .parity_err_o (parity_err_o),       // 1T flag indicates parity error (if parity is enabled)
        // Input RX signal from the FPGA pin
        .rx_pin_i (tx_pin_o)
    );



    // Clock Generator
    initial clk = 1'b0;
    always #(20)
    begin
        clk = ~clk;
    end

    // Baud rate generator
    always @(posedge clk)
    begin
        if (!resetn)
        begin
            prescaler_r <= 0;
        end else begin
            prescaler_r <= prescaler_r + 1;
        end
    end

    assign uart_cken_i = (prescaler_r == 0);


    initial
    begin
        resetn <= 0;
        parity_en_i <= 0;
        parity_type_i <= 0;
        tx_byte_i <= 0;
        tx_en_i <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        resetn <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    
        tx_byte_i <= 8'h53;
        tx_en_i <= 1;
        @(posedge clk);
        tx_en_i <= 0;        
        @(posedge clk);
        @(posedge clk);

        while (!tx_ready_o)
        begin
            @(posedge clk);
        end

        // #200000;
        
        tx_byte_i <= 8'hAA;
        tx_en_i <= 1;
        parity_en_i <= 1;
        @(posedge clk);
        tx_en_i <= 0;
        @(posedge clk);
        while (!tx_ready_o)
        begin
            @(posedge clk);
        end
        
        #200;
        $finish;
    end

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);
    end

endmodule
