module tb_nora ();

    reg FPGACLK;

// CPU interface
    wire [7:0] CD;         // CPU data bus
    wire [15:12] CA;       // CPU address bus

    wire CRESn;           // CPU reset
    wire CIRQn;           // CPU IRQ request
    wire CNMIn;           // CPU NMI request
    wire CABORTn;         // CPU ABORT request (16b only)
    wire CPHI2;           // CPU clock
    wire CBE;             // CPU bus-enable

    wire CRDY;             // CPU ready signal
    wire CSOB_MX;          // CPU SOB (set overflow - 8b) / MX (16b)

    wire CSYNC_VPA;        // CPU SYNC (8b) / VPA (16b) signal
    wire CMLn = 1;             // CPU memory lock
    wire CVPn = 1;             // CPU vector pull signal
    wire CVDA = 1;             // CPU VDA (16b only)
    wire CEF = 1;              // CPU EF (16b only)
    wire CRWn;             // CPU R/W signal


// Memory bus
    wire [20:12] MAH;      // memory address high bits 12-20: private to FPGA = output
    wire [11:0] MAL;      // memory address low bits 0-11: shared with CPU = bidi
    wire [7:0] MD;         // Memory data bus
    wire M1CSn;           // SRAM chip-select
    wire MRDn;            // Memory Read
    wire MWRn;            // Memory Write

    wire CPULED0;
    wire CPULED1;

    wire ICD_CSn = 1'b1;
    wire ICD_MOSI = 1'b1;
    wire ICD_MISO;
    wire ICD_SCK = 1'b1;


    top dut0 (
    // 12MHz FPGA clock input
        .FPGACLK (FPGACLK),

    // CPU interface
        .CD (CD),         // CPU data bus
        .CA (CA),       // CPU address bus

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
        .VIAIRQ (1'b1),
        // output PERIRESn,

        .I2C_SCL (1'b1),
        .I2C_SDA (1'b1),

        .NESLATCH (1'b1),
        .NESCLOCK (1'b1),
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

        // output VCS0n,
        // output VCS1n,
        // output VCS2n,
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



endmodule
