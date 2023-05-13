`timescale 1ns/100ps

module tb_ps2port ( );

    // Global signals
    reg           clk6x;      // 48MHz
    reg           resetn;     // sync reset
    reg           ck1us;      // 1 usec-spaced pulses, 1T long
    reg [6:0]   ck1us_counter;

    // PS2 port signals
    reg           PS2_CLK;        // CLK line state
    reg           PS2_DATA;       // DATA line state
    wire      PS2_CLKDR0;     // 1=>drive zero on CLK, 0=>HiZ
    wire      PS2_DATADR0;    // 1=>drive zero on DATA, 0=>HiZ
    // 
    wire [7:0]  code_rx_o;       // received scan-code
    wire        code_rx_v_o;       // scan-code valid
    // Host-to-Device (TX) interface
    reg [7:0]     cmd_tx_i;         // command byte to send   
    reg           cmd_tx_v_i;         // send the command byte
    wire      busy;             // ongoing TX (not accepting a new command)
    wire      tx_acked_o;
    wire      tx_errd_o;


    // generate 1us pulses for PS2 port
    always @(posedge clk6x) 
    begin
        // reset pulse
        ck1us <= 0;
        if (!resetn)
        begin
            // reset the counter
            ck1us_counter <= 7'd47;
        end else begin
            // is expired?
            if (ck1us_counter == 0)
            begin
                // expired -> generate ck1us pulse
                ck1us <= 1;
                // reset the counter
                ck1us_counter <= 7'd47;
            end else begin
                // counting
                ck1us_counter <= ck1us_counter - 1;
            end
        end
    end


    ps2_port dut
    (
        // Global signals
        .clk6x,      // 48MHz
        .resetn,     // sync reset
        .ck1us,      // 1 usec-spaced pulses, 1T long
        // PS2 port signals
        .PS2_CLK,        // CLK line state
        .PS2_DATA,       // DATA line state
        .PS2_CLKDR0,     // 1=>drive zero on CLK, 0=>HiZ
        .PS2_DATADR0,    // 1=>drive zero on DATA, 0=>HiZ
        // 
        .code_rx_o,       // received scan-code
        .code_rx_v_o,       // scan-code valid
        //
        .cmd_tx_i,         // command byte to send   
        .cmd_tx_v_i,         // send the command byte
        .busy,             // ongoing TX (not accepting a new command)
        .tx_acked_o,
        .tx_errd_o
    );


    // Clock Generator
    initial clk6x = 1'b0;
    always #(20)
    begin
        clk6x = ~clk6x;
    end

    integer j;
    
    // reg [7:0]   txdata;
    // reg         txparity;


    task send;
        input [7:0] txdata;
        reg         txparity;
        begin
            txparity = 1'b0;
            
            // START
            #16500 PS2_DATA = 0;
            #16500 PS2_CLK = 0;
            
            #33000 PS2_CLK = 1;

            for (j = 0; j < 8; ++j)
            begin
                // DATA BIT j
                #16500 PS2_DATA = (txdata >> j);
                txparity = txparity ^ (txdata >> j);
                #16500 PS2_CLK = 0;
                
                #33000 PS2_CLK = 1;
            end

            // PARITY
            #16500 PS2_DATA = ~txparity;
            #16500 PS2_CLK = 0;

            #33000 PS2_CLK = 1;

            // STOP
            #16500 PS2_DATA = 1;
            #16500 PS2_CLK = 0;

            #33000 PS2_CLK = 1;
            
        end
    endtask

    task receive;
        input [7:0] cmd;
        begin
            cmd_tx_i = cmd;
            @(posedge clk6x);
            cmd_tx_v_i = 1;
            @(posedge clk6x);
            cmd_tx_v_i = 0;
            @(posedge clk6x);

            @(negedge PS2_CLKDR0);

            for (j = 0; j < 10; ++j)
            begin
                #33000 PS2_CLK = 0;
                #33000 PS2_CLK = 1;
            end

            // output the ACK=0
            #16500 PS2_DATA = 0;
            #16500 PS2_CLK = 0;
            #33000 PS2_CLK = 1;
            #16500 PS2_DATA = 1;


        end
    endtask

    initial
    begin
        PS2_CLK = 1;
        PS2_DATA = 1;
        resetn = 1'b0;
        cmd_tx_i = 8'h00;
        cmd_tx_v_i = 0;
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end

        resetn = 1'b1;
        for (j = 0; j < 200; ++j)
        begin
            @(posedge clk6x);
        end


        // txdata = 8'hC7;
        // txparity = 0;

        send(8'hC7);
        #100000;
        send(8'h7C);

        #100000;

        receive(8'h45);

        #100000;

        $finish;
    end


    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_ps2port.vcd");
        $dumpvars(0,tb_ps2port);
    end

endmodule
