`timescale 1ns/100ps

module tb_i2c ( );

    // Global signals
    reg           clk6x;      // 48MHz
    reg           resetn;     // sync reset
    // I2C bus
    reg           I2C_SDA_i;
    wire        I2C_SDA;
    wire        I2C_SDADR0_o;
    reg           I2C_SCL_i;
    // Device interface
    wire        devsel_o;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    wire          rw_bit_o;           // Read/nWrite bit, only valid when devsel_o=1
    wire [7:0]    rxbyte_o;          // the received byte for device
    wire          rxbyte_v_o;         // valid received byte (for 1T) for Write transfers
    reg  [7:0]    txbyte_i;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    wire        txbyte_deq_o;        // the txbyte has been consumed (1T)
    wire       tx_nacked_o;         // master NACKed the last byte!


    i2c_slave #(
        .SLAVE_ADDRESS (8'h42)
    ) dut (
        // Global signals
        clk6x,      // 48MHz
        resetn,     // sync reset
        // I2C bus
        I2C_SDA,
        I2C_SDADR0_o,
        I2C_SCL_i,
        // Device interface
        devsel_o,           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
        rw_bit_o,           // Read/nWrite bit, only valid when devsel_o=1
        rxbyte_o,          // the received byte for device
        rxbyte_v_o,         // valid received byte (for 1T) for Write transfers
        txbyte_i,           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
        txbyte_deq_o,        // the txbyte has been consumed (1T)
        tx_nacked_o
    );

    assign I2C_SDA = I2C_SDA_i & (~I2C_SDADR0_o);

    // Clock Generator
    initial clk6x = 1'b0;
    always #(20)
    begin
        clk6x = ~clk6x;
    end

    integer j;


    task send_start;
        begin
            I2C_SDA_i = 0;
            #5000;
            I2C_SCL_i = 0;
            #2500;
        end
    endtask

    task send_data;
        input [7:0] txdata;
        begin
            for (j = 0; j < 8; ++j)
            begin
                I2C_SDA_i = txdata[7];
                #2500;
                txdata = { txdata[6:0], 1'b0 };
                I2C_SCL_i = 1;
                #5000;
                I2C_SCL_i = 0;
                #2500;
            end
            I2C_SDA_i = 1;
        end
    endtask

    task recv_ack;
        begin
            I2C_SDA_i = 1;
            #2500;
            I2C_SCL_i = 1;
            #5000;
            I2C_SCL_i = 0;
            #2500;
        end
    endtask

    task send_stop;
        begin
            I2C_SDA_i = 0;
            #2500;
            I2C_SCL_i = 1;
            #5000;
            I2C_SDA_i = 1;
            #5000;
        end
    endtask

    task recv_data;
        begin
            I2C_SDA_i = 1;
            for (j = 0; j < 8; ++j)
            begin
                // I2C_SDA_i = txdata[7];
                #2500;
                // txdata = { txdata[6:0], 1'b0 };
                I2C_SCL_i = 1;
                #5000;
                I2C_SCL_i = 0;
                #2500;
            end
        end
    endtask

    task send_ack;
        input ackbit;
        begin
            I2C_SDA_i = ackbit;
            #2500;
            I2C_SCL_i = 1;
            #5000;
            I2C_SCL_i = 0;
            #2500;
            I2C_SDA_i = 1;
        end
    endtask

    initial
    begin
        I2C_SCL_i = 1;
        I2C_SDA_i = 1;
        resetn = 1'b0;
        txbyte_i = 8'h00;
        for (j = 0; j < 20; ++j)
        begin
            @(posedge clk6x);
        end

        resetn = 1'b1;
        for (j = 0; j < 200; ++j)
        begin
            @(posedge clk6x);
        end


        send_start();
        send_data(8'h42);       // write
        recv_ack();
        send_data(8'h23);
        recv_ack();
        send_data(8'h45);
        recv_ack();
        send_stop();
        #100000;

        send_start();
        send_data(8'h43);       // read
        txbyte_i = 8'h56;
        recv_ack();
        recv_data();
        txbyte_i = 8'hAB;
        send_ack(0);        // next byte
        recv_data();
        send_ack(1);        // last byte
        send_stop();


        #100000;

        // receive(8'h45);

        #100000;

        $finish;
    end


    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_i2c.vcd");
        $dumpvars(0,tb_i2c);
    end


endmodule
