`timescale 1ns/100ps

module tb_i2c_master ();

    // Global signals
    reg           clk;        // 48MHz
    reg           resetn;     // sync reset
    // I2C bus
    wire           I2C_SDA;
    wire           I2C_SCL;

    reg           I2C_SDA_i = 1;
    wire          I2C_SDADR0_o;       // 1 will drive SDA low
    reg           I2C_SCL_i = 1;
    wire          I2C_SCLDR0_o;       // 1 will drive SCL low
    // Host interface
    reg [2:0]     cmd_i;      // command
    wire [7:0]    status_o;     // bus operation in progress
    reg [7:0]     data_wr_i;  // data for transmitt
    wire [7:0]      data_rd_o;      // data received

    i2c_master dut (
        // Global signals
        .clk    (clk),        // 48MHz
        .resetn (resetn),     // sync reset
        // I2C bus
        .I2C_SDA_i (I2C_SDA),
        .I2C_SDADR0_o (I2C_SDADR0_o),       // 1 will drive SDA low
        .I2C_SCL_i  (I2C_SCL),
        .I2C_SCLDR0_o (I2C_SCLDR0_o),       // 1 will drive SCL low
        // Host interface
        .cmd_i  (cmd_i),      // command
        .status_o (status_o),     // bus operation in progress
        .data_wr_i  (data_wr_i),  // data for transmitt
        .data_rd_o  (data_rd_o)      // data received
    );

    assign I2C_SDA = I2C_SDA_i & (~I2C_SDADR0_o);
    assign I2C_SCL = I2C_SCL_i & (~I2C_SCLDR0_o);

    // Clock Generator
    initial clk = 1'b0;
    always #(20)
    begin
        clk = ~clk;
    end

    // definition of commands
    localparam CMD_NOOP             = 3'b000;
    localparam CMD_STARTADDR        = 3'b001;   // send START + WRBYTE_RDACK
    localparam CMD_WRBYTE_RDACK     = 3'b010;   // send BYTE + read ACK-bit in D0
    localparam CMD_RDBYTE           = 3'b011;   // recv BYTE
    localparam CMD_WRACK            = 3'b100;   // send ACK (0)
    localparam CMD_WRNACK           = 3'b101;   // send NACK (1)
    localparam CMD_STOP             = 3'b111;   // generate STOP, release bus

    initial
    begin
        resetn <= 0;
        cmd_i <= CMD_NOOP;
        data_wr_i <= 8'h00;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        resetn <= 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // Generate START, send ADDRESS, read ACK
        cmd_i <= CMD_STARTADDR;
        data_wr_i <= 8'hA5;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        cmd_i <= CMD_NOOP;
        @(posedge clk);
        while (status_o[7] == 1)
        begin
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);


        // Read BYTE from device
        cmd_i <= CMD_RDBYTE;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        cmd_i <= CMD_NOOP;
        @(posedge clk);
        while (status_o[7] == 1)
        begin
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);

        // Write ACK
        cmd_i <= CMD_WRACK;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        cmd_i <= CMD_NOOP;
        @(posedge clk);
        while (status_o[7] == 1)
        begin
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);


        // Write BYTE to device, read ACK
        cmd_i <= CMD_WRBYTE_RDACK;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        cmd_i <= CMD_NOOP;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        I2C_SCL_i <= 0;
        while (status_o[7] == 1)
        begin
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);

        // Generate STOP
        cmd_i <= CMD_STOP;
        @(posedge clk);
        @(posedge clk);
        cmd_i <= CMD_NOOP;
        while (status_o[7] == 1)
        begin
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);




        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        $finish;
    end


    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_i2c_master.vcd");
        $dumpvars(0, tb_i2c_master);
    end


endmodule
