`timescale 1ns/100ps

module tb_nora ();

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

    reg FPGACLK;

// CPU interface
    // reg [15:12] CA;       // CPU address bus
    reg [15:0] cpuCA;
    reg [7:0]  cpuCD;

// SRAM interface
    reg [7:0] sramMD;

    wire CRESn;           // CPU reset
    wire CIRQn;           // CPU IRQ request
    wire CNMIn;           // CPU NMI request
    wire CABORTn;         // CPU ABORT request (16b only)
    wire CPHI2;           // CPU clock
    wire CBE;             // CPU bus-enable

    wire CRDY = 1;             // CPU ready signal
    wire CSOB_MX = 1;          // CPU SOB (set overflow - 8b) / MX (16b)

    reg CSYNC_VPA;        // CPU SYNC (8b) / VPA (16b) signal
    wire CMLn = 1;             // CPU memory lock
    wire CVPn = 1;             // CPU vector pull signal
    wire CVDA = 1;             // CPU VDA (16b only)
    wire CEF = 1;              // CPU EF (16b only)
    reg CRWn;             // CPU R/W signal

    wire [7:0] CD = (CBE && !CRWn) ? cpuCD : 8'hZZ;         // CPU data bus

// Memory bus
    wire [20:12] MAH;      // memory address high bits 12-20: private to FPGA = output
    wire [11:0] MAL = (CBE) ? cpuCA[11:0] : 12'hZZZ;      // memory address low bits 0-11: shared with CPU = bidi
    wire [7:0] MD = (!M1CSn && !MRDn) ? sramMD : 8'hZZ;         // Memory data bus
    wire M1CSn;           // SRAM chip-select
    wire MRDn;            // Memory Read
    wire MWRn;            // Memory Write

    wire CPULED0;
    wire CPULED1;

    wire VCS0n_VERA;
    wire VCS1n_AIO;
    wire VCS2n_ENET;

    wire ICD_CSn = 1'b1;
    wire ICD_MOSI = 1'b1;
    wire ICD_MISO = 1'b1;
    wire ICD_SCK = 1'b1;


    top dut0 (
    // 12MHz FPGA clock input
        .FPGACLK (FPGACLK),

    // CPU interface
        .CD (CD),         // CPU data bus
        .CA (cpuCA[15:12]),       // CPU address bus

        .CRESn (CRESn),           // CPU reset
        .CIRQn (CIRQn),           // CPU IRQ request
        .CNMIn (CNMIn),           // CPU NMI request
        .CABORTn (CABORTn),         // CPU ABORT request (16b only)
        .CPHI2 (CPHI2),           // CPU clock
        .CBE (CBE),             // CPU bus-enable

        .CRDY (CRDY),             // CPU ready signal
        .CSOB_MX (CSOB_MX),          // CPU SOB (set overflow - 8b) / MX (16b)

        .CSYNC_VPA (CSYNC_VPA),        // CPU SYNC (8b) / VPA (16b) signal
        .CMLn (CMLn),             // CPU memory lock
        .CVPn (CVPn),             // CPU vector pull signal
        .CVDA (CVDA),             // CPU VDA (16b only)
        .CEF (CEF),              // CPU EF (16b only)
        .CRWn (CRWn),             // CPU R/W signal


    // Memory bus
        .MAH (MAH),      // memory address high bits 12-20: private to FPGA = output
        .MAL (MAL),      // memory address low bits 0-11: shared with CPU = bidi
        .MD (MD),         // Memory data bus
        .M1CSn (M1CSn),           // SRAM chip-select
        .MRDn (MRDn),            // Memory Read
        .MWRn (MWRn),            // Memory Write

    // VIA interface
        // output VIAPHI2,
        // output VIACS,
        // .VIAIRQ (1'b1),
        // output PERIRESn,

        // .I2C_SCL (1'b1),
        // .I2C_SDA (1'b1),

        // .NESLATCH (1'b1),
        // .NESCLOCK (1'b1),
        .NESDATA1 (1'b1),
        .NESDATA0 (1'b1),

        .CPULED0 (CPULED0),
        .CPULED1 (CPULED1),

    // additional ILI SPI ports
        // output ILICSn,
        // output ILIDC,
        // output TCSn,
        .TIRQn (1'b1),

    // PS2 ports
        .PS2K_CLK (1'b1),
        .PS2K_DATA (1'b1),
        // output PS2K_CLKDR,
        // output PS2K_DATADR,
        
        .PS2M_CLK (1'b1),
        .PS2M_DATA (1'b1),
        // output PS2M_CLKDR,
        // output PS2M_DATADR,

    // UART port
        // output UART_CTS,
        .UART_RTS (1'b1),
        // output UART_TX,
        .UART_RX (1'b1),

    // VERA FPGA
        .VERADONE (1'b1),
        .VERARSTn (1'b1),
        .VERAFCSn (1'b1),
        .ICD2VERAROM (1'b1),

        .VCS0n (VCS0n_VERA),
        .VCS1n (VCS1n_AIO),
        .VCS2n (VCS2n_ENET),
        .VIRQn (1'b1),
        .VAUX0 (1'b1),
        .VAUX1 (1'b1),
        .VAUX2 (1'b1),

    // ICD SPI-slave interface
        .ICD_CSn (ICD_CSn),
        .ICD_MOSI (ICD_MOSI),
        .ICD_MISO (ICD_MISO),
        .ICD_SCK (ICD_SCK),

    // Button input
        .ATTBTN (1'b1),

    // Master SPI interface for SPI-flash access
        // output FMOSI,
        .FMISO (1'b1)
        // output FSCK,
        // output FLASHCSn
    );

    // Clock Generator
    initial FPGACLK = 1'b0;
    always #(20)
    begin
        FPGACLK = ~FPGACLK;
    end

    // data that the CPU has read from NORA/SRAM
    reg [7:0] tb_cpuDataRead;

    // generate CPU read transaction
    task cpu_read;
        input [15:0] addr;
        begin
            #40;        // wait tADS=40ns max.
            cpuCA = addr;
            cpuCD = 8'hZZ;
            CRWn = 1'b1;
            CSYNC_VPA = 1'b0;
            @(posedge CPHI2);
            #(60-15);       // tDSR=15ns min before negedge CPHI2
            // tb_cpuDataRead = CD;
            @(negedge CPHI2);
            #10;            // tDHR=10ns max after negedge CPHI2
            tb_cpuDataRead = CD;
        end
    endtask

    // generate CPU write transaction
    task cpu_write;
        input [15:0] addr;
        input [7:0] wdata;
        begin
            #40;        // wait tADS=40ns max.
            cpuCA = addr;
            cpuCD = 8'hXX;
            CRWn = 1'b0;
            CSYNC_VPA = 1'b0;
            @(posedge CPHI2);
            #40;       // tMDS=40ns max after posedge CPHI2
            cpuCD = wdata;
            @(negedge CPHI2);
            cpuCD = #10 16'hXX;
            CRWn = #10 1'b1;
        end
    endtask

    initial
    begin
        // define initial values of inputs to NORA
        cpuCA = 16'hFFFF;
        cpuCD = 8'hZZ;
        // MAL = 12'hFFF;
        // CD = 8'h00;
        // CRDY = 1'b1;
        CRWn = 1'b1;
        // CSOB_MX = 1'b1;
        CSYNC_VPA = 1'b0;
        // ICD_MISO = 1'b1;

        @(negedge CPHI2);
        @(negedge CPHI2);

        // test-writes CPU->SRAM
        cpu_write(16'h0010, 8'h12);
        cpu_write(16'h0011, 8'h34);
        cpu_write(16'h0012, 8'h56);
        cpu_write(16'h0013, 8'h78);
        
        // test-reads SRAM->CPU
        cpu_read(16'h0010);  `assert(tb_cpuDataRead, 8'h12);
        cpu_read(16'h0011);  `assert(tb_cpuDataRead, 8'h34);
        cpu_read(16'h0012);  `assert(tb_cpuDataRead, 8'h56);
        cpu_read(16'h0013);  `assert(tb_cpuDataRead, 8'h78);

        // write to bank regs
        cpu_write(16'h0000, 8'hAB);         // RAMBANK
        cpu_write(16'h0001, 8'h0C);         // ROMBANK

        // read from bank regs
        cpu_read(16'h0000);  `assert(tb_cpuDataRead, 8'hAB);
        cpu_read(16'h0001);  `assert(tb_cpuDataRead, 8'h0C);

        // write to VIA
        cpu_write(16'h9F02, 8'h03);         // VIA1/DDRB [1:0] config to outputs
        cpu_write(16'h9F00, 8'h00);         // VIA1/ORB set to 00
        cpu_read(16'h9F02);     `assert(tb_cpuDataRead, 8'h03);
        cpu_write(16'h9F00, 8'h01);         // VIA1/ORB set to 01
        cpu_write(16'h9F00, 8'h02);         // VIA1/ORB set to 01
        cpu_read(16'h9F00);     `assert(tb_cpuDataRead, 8'hC2);         // fixed upper signal's levels

        // write to VERA
        cpu_write(16'h9F20, 8'h12);

        #1000;
        $display("=== TESTBENCH OK ===");
        $finish;
    end

    // ------------------------------------------------------
    // simulation of SRAM
    reg [7:0] sram_block [255:0];

    // SRAM read
    always @(MRDn, M1CSn)
    begin
        if ((MRDn == 0) && (M1CSn == 0))
        begin
            sramMD <= #20 sram_block[MAL[7:0]];
        end else begin
            sramMD <= 8'hXX;
        end
    end

    // SRAM write
    always @(posedge MWRn)
    begin
        if (M1CSn == 0)
        begin
            sram_block[MAL[7:0]] <= MD;
        end
    end
    // ------------------------------------------------------

    // Do this in your test bench to generate VCD waves
    initial
    begin
        $dumpfile("tb_nora.vcd");
        $dumpvars(0,tb_nora);
    end


endmodule
