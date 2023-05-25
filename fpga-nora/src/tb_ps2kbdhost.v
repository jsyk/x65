`timescale 1ns/100ps

module tb_ps2kbdhost ();

    // Global signals
    reg           clk6x;      // 48MHz
    reg           resetn;     // sync reset
    wire           ck1us;      // 1 usec-spaced pulses, 1T long
    reg [6:0]   ck1us_counter;

    // PS2 port signals
    reg           PS2_CLK;        // CLK line state
    reg           PS2_DATA;       // DATA line state
    wire      PS2_CLKDR0;     // 1=>drive zero on CLK, 0=>HiZ
    wire      PS2_DATADR0;    // 1=>drive zero on DATA, 0=>HiZ

    pulser pulser_1us
    (
        .clk6x (clk6x),       // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us)
    );

    reg        devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    reg        rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    reg [7:0]  rxbyte;          // the received byte for device
    reg        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    wire [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    reg        txbyte_deq;       // the txbyte has been consumed (1T)

    ps2_kbd_host dut (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us),      // 1us pulses
        // SMC interface
        .devsel_i (devsel),           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
        .rw_bit_i (rw_bit),           // Read/nWrite bit, only valid when devsel_i=1
        .rxbyte_i (rxbyte),          // the received byte for device
        .rxbyte_v_i (rxbyte_v),         // valid received byte (for 1T) for Write transfers
        .txbyte_o (txbyte),           // the next byte to transmit from device; shall be valid anytime devsel_i=1 && rw_bit_i=1
        .txbyte_deq_i (txbyte_deq),       // the txbyte has been consumed (1T)
        // PS2 Keyboard port - FPGA pins
        .PS2K_CLK (PS2_CLK),
        .PS2K_DATA (PS2_DATA),
        .PS2K_CLKDR (PS2_CLKDR0),         // 1=drive PS2K_CLK to zero (L)
        .PS2K_DATADR (PS2_DATADR0)         // 1=drive PS2K_DATA to zero (L)
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


    // simulate sending from PS2 device
    task send;
        input [7:0] txdata;     // the byte to send from device to port
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

    // simulate receiving in PS2 device
    task receive;
        begin
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

    task read_smc_reg;
        input [7:0]     smc_reg;
        begin
            devsel <= 1'b1; rw_bit <= 1'b0;     // write
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            rxbyte <= smc_reg;
            rxbyte_v <= 1'b1;
            @(posedge clk6x);
            rxbyte_v <= 1'b0;
            @(posedge clk6x);
            devsel <= 1'b0;                     // restart
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            devsel <= 1'b1; rw_bit <= 1'b1;     // read
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            txbyte_deq <= 1'b1;
            @(posedge clk6x);
            txbyte_deq <= 1'b0;
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            devsel <= 1'b0;
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
        end
    endtask

    task write_smc_reg_1b;
        input [7:0]     smc_reg;
        input [7:0]     dataval;
        begin
            devsel <= 1'b1; rw_bit <= 1'b0;     // write
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            rxbyte <= smc_reg;
            rxbyte_v <= 1'b1;
            @(posedge clk6x);
            rxbyte_v <= 1'b0;
            @(posedge clk6x);
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            rxbyte <= dataval;
            rxbyte_v <= 1'b1;
            @(posedge clk6x);
            rxbyte_v <= 1'b0;
            @(posedge clk6x);
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            devsel <= 1'b0;
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
        end
    endtask

    task write_smc_reg_2b;
        input [7:0]     smc_reg;
        input [7:0]     dataval1;
        input [7:0]     dataval2;
        begin
            devsel <= 1'b1; rw_bit <= 1'b0;     // write
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            rxbyte <= smc_reg;
            rxbyte_v <= 1'b1;
            @(posedge clk6x);
            rxbyte_v <= 1'b0;
            @(posedge clk6x);
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
            rxbyte <= dataval1;
            rxbyte_v <= 1'b1;
            @(posedge clk6x);
            rxbyte_v <= 1'b0;
            @(posedge clk6x);
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);

            rxbyte <= dataval2;
            rxbyte_v <= 1'b1;
            @(posedge clk6x);
            rxbyte_v <= 1'b0;
            @(posedge clk6x);
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);

            devsel <= 1'b0;
            @(posedge clk6x); @(posedge clk6x); @(posedge clk6x);
        end
    endtask

    initial
    begin
        PS2_CLK = 1;
        PS2_DATA = 1;
        resetn = 1'b0;
        devsel = 1'b0;
        rw_bit = 1'b1;
        rxbyte = 8'h00;
        rxbyte_v = 1'b0;
        txbyte_deq = 1'b0;
        
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end

        resetn = 1'b1;
        for (j = 0; j < 200; ++j)
        begin
            @(posedge clk6x);
        end


        read_smc_reg(8'h07);        // smc reg addr = 07 = SMCREG_READ_KBD_BUF
        // expected: 00

        send(8'hC7);
        #100000;
        send(8'h7C);

        #100000;

        read_smc_reg(8'h07);        // smc reg addr = 07 = SMCREG_READ_KBD_BUF
        // expected: C7

        #1000;

        read_smc_reg(8'h07);        // smc reg addr = 07 = SMCREG_READ_KBD_BUF
        // expected 7C

        #1000;

        write_smc_reg_1b(8'h19, 8'hA5);         // smc reg addr 19 = SMCREG_SEND_PS2_KBD_CMD

        #100000;

        receive();

        #100000;

        write_smc_reg_2b(8'h1A, 8'h55, 8'hAA);         // smc reg addr 1A = SMCREG_SEND_PS2_KBD_2BCMD

        #100000;
        receive();
        receive();

        #100000;


        $finish;
    end


    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_ps2kbdhost.vcd");
        $dumpvars(0, tb_ps2kbdhost);
    end

endmodule
