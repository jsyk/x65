// `include "pll.v"
// `include "blinker.v"

module top (
// 12MHz FPGA clock input
    input FPGACLK,
// CDONE / LED output
    // output CDONE,

// CPU interface
    inout [7:0] CD,         // CPU data bus
    input [15:12] CA,       // CPU address bus

    output CRESn,           // CPU reset
    output CIRQn,           // CPU IRQ request
    output CNMIn,           // CPU NMI request
    output CABORTn,         // CPU ABORT request (16b only)
    output CPHI2,           // CPU clock
    output CBE,             // CPU bus-enable

    inout CRDY,             // CPU ready signal
    inout CSOB_MX,          // CPU SOB (set overflow - 8b) / MX (16b)

    input CSYNC_VPA,        // CPU SYNC (8b) / VPA (16b) signal
    input CMLn,             // CPU memory lock
    input CVPn,             // CPU vector pull signal
    input CVDA,             // CPU VDA (16b only)
    input CEF,              // CPU EF (16b only)
    input CRWn,             // CPU R/W signal


// Memory bus
    output [20:12] MAH,      // memory address high bits 12-20: private to FPGA = output
    inout [11:0] MAL,      // memory address low bits 0-11: shared with CPU = bidi
    inout [7:0] MD,         // Memory data bus
    output M1CSn,           // SRAM chip-select
    output MRDn,            // Memory Read
    output MWRn,            // Memory Write

// VIA interface
    output VIAPHI2,         // TBD remove
    output VIACS,           // TBD remove
    input VIAIRQ,           // TBD remove
    output PERIRESn,        // TBD maybe remove

    inout I2C_SCL,
    inout I2C_SDA,

    inout NESLATCH,
    inout NESCLOCK,
    inout NESDATA1,
    inout NESDATA0,

    inout CPULED0,
    inout CPULED1,

// additional ILI SPI ports
    output ILICSn,
    output ILIDC,
    output TCSn,
    input TIRQn,

// PS2 ports
    input PS2K_CLK,
    input PS2K_DATA,
    output PS2K_CLKDR,
    output PS2K_DATADR,
    
    input PS2M_CLK,
    input PS2M_DATA,
    output PS2M_CLKDR,
    output PS2M_DATADR,

// UART port
    output UART_CTS,
    input UART_RTS,
    output UART_TX,
    input UART_RX,

// VERA FPGA
    input VERADONE,
    input VERARSTn,
    input VERAFCSn,
    input ICD2VERAROM,

    output VCS0n,               // VERA
    output VCS1n,               // AURA
    output VCS2n,               // ENET
    input VIRQn,            // IRQ from VERA & AURA & ENET, active low.
    input VAUX0,
    input VAUX1,
    input VAUX2,

// ICD SPI-slave interface
    input ICD_CSn,
    input ICD_MOSI,
    output ICD_MISO,
    input ICD_SCK,

// Button input
    input ATTBTN,

// Master SPI interface for SPI-flash access
    output FMOSI,
    input FMISO,
    output FSCK,
    output FLASHCSn
);

    wire clk6x;
    wire clk6x_locked;
    wire resetn;

`ifdef SIMULATION
    // simulation - skip PLL
    assign clk6x = FPGACLK;
    assign clk6x_locked = 1'b1;
`else
    // synthesis PLL
    pll pll0 ( .clock_in(FPGACLK), .clock_out(clk6x), .locked(clk6x_locked));
`endif

    /**
    * Autonomous reset generator
    */
    resetgen rstgen0 (
        .clk (clk6x), .clklocked (clk6x_locked), .rstreq(1'b0),
        .resetn (resetn)
    );

    wire blinkerled;

    blinker //#(.TOP(10))
    blnk0 (
        .clk (clk6x), .resetn (resetn),
        .blink_en (1'b1),
        .led_o (blinkerled)
    );
 
    wire  ph_run_cpu;
    wire  busct_run_cpu;
    wire  stopped_cpu;
    wire  setup_cs;   // catch CPU address and setup the CSx signals
    wire  release_wr;  // release write signal now, to have a hold before the cs-release
    wire  release_cs;  // CPU access is complete, release the CS

    /* 
    * Phaser generates CPU and VIA phased clocks CPHI2, VPHI2
    * and supporting signals for control of the cpu and memory bus.
    */
    phaser ph0 ( 
        .clk6x  (clk6x),
        .resetn   (resetn),
        .run    (ph_run_cpu),
        .stopped (stopped_cpu),
        .cphi2  (CPHI2),
        .vphi2  (VIAPHI2),
        .setup_cs (setup_cs),
        .release_wr (release_wr),
        .release_cs (release_cs)
    );

    // CPU aux signals
    wire [7:0] cpu_db_o;
    wire [7:0] mem_db_o;
    wire [11:0] mem_abl_o;


    // NORA master interface - internal debug controller
    wire    [23:0]  nora_mst_addr;
    wire    [7:0]   nora_mst_datawr;
    wire    [7:0]   nora_mst_datard;
    wire            nora_mst_ack;                 // end of access, also nora_mst_datard_o is valid now.
    // wire            nora_mst_req_BOOTROM;
    // wire            nora_mst_req_BANKREG;
    // wire            nora_mst_req_SCRB;
    wire            nora_mst_req_SRAM;
    wire            nora_mst_req_OTHER;
    // wire            nora_mst_req_VIA;
    // wire            nora_mst_req_VERA;
    wire            nora_mst_rwn;
    // NORA slave interface - internal devices
    wire    [15:0]  nora_slv_addr;
    wire    [7:0]   nora_slv_datawr;     // write data = available just at the end of cycle!!
    wire            nora_slv_datawr_valid;      // flags nora_slv_datawr_o to be valid
    wire    [7:0]   nora_slv_datard;
    wire            nora_slv_req_BOOTROM;
    wire            nora_slv_req_SCRB;
    wire            nora_slv_req_VIA1;
    wire            nora_slv_rwn;
    // Bank parameters from SCRB
    // wire    [7:0]   rambank_mask = 8'hFF;
    wire    [7:0]   rambank_mask = 8'h7F;       // X16 compatibility: allow only 128 RAM banks after reset

    // CPU address bus -virtual internal `input' signal
    // create the 16-bit CPU bus address by concatenating the two bus signals
    wire [15:0]     cpu_ab = { CA, MAL };
    reg [15:0]      cpu_ab_r;
    reg             csob_mx_r, csync_vpa_r, cmln_r, cvpn_r, cvda_r, cef_r, crwn_r;

    // sample address and CPU status outputs for trace buffer at setup_cs
    always @(posedge clk6x)
    begin
        if (setup_cs)
        begin
            cpu_ab_r <= cpu_ab;
            csob_mx_r <= CSOB_MX;
            csync_vpa_r <= CSYNC_VPA;
            cmln_r <= CMLn;
            cvpn_r <= CVPn;
            cvda_r <= CVDA;
            cef_r <= CEF;
            crwn_r <= CRWn;
        end
    end

    // Trace signal
    wire [39:0]   cpubus_trace = {
        // trace bytes [4], [3]:
            cpu_ab_r,        // CPU address bus, [15:12][11:0] = 16b
        // trace byte [2]:
            CD,             // CPU data bus, 8b
        // trace byte [1]:
            4'h0,
            CRESn,           // CPU reset
            CIRQn,           // CPU IRQ request
            CNMIn,           // CPU NMI request
            CABORTn,         // CPU ABORT request (16b only)
        // trace byte [0]:
            CRDY,             // CPU ready signal
            csob_mx_r,          // CPU SOB (set overflow - 8b) / MX (16b)
            csync_vpa_r,        // CPU SYNC (8b) / VPA (16b) signal
            cmln_r,             // CPU memory lock
            cvpn_r,             // CPU vector pull signal
            cvda_r,             // CPU VDA (16b only)
            cef_r,              // CPU EF (16b only)
            crwn_r              // CPU R/W signal
        };

    /* ICD SPI Slave - MISO driver */
    wire icd_miso_o;
    wire icd_miso_dr;
    assign ICD_MISO = (icd_miso_dr) ? icd_miso_o : 1'bZ;

    /* ICD RX/TX bytes */
    wire [7:0]  icd_rx_byte;
    wire        icd_rx_hdr;
    wire        icd_rx_db;
    //
    wire [7:0]  icd_tx_byte;
    wire        icd_tx_en;

    wire        icd_run_cpu;
    wire        icd_cpu_force_resn;

    /**
    * SPI Slave (Target) - for ICD function.
    */
    spi_slave icdspi (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // SPI Slave signals
        .spi_clk_i (ICD_SCK),
        .spi_csn_i (ICD_CSn),
        .spi_mosi_i (ICD_MOSI),
        .spi_miso_o (icd_miso_o),
        .spi_miso_drive_o (icd_miso_dr),
        // Received data
        .rx_byte_o (icd_rx_byte),     // received byte data
        .rx_hdr_en_o (icd_rx_hdr),    // flag: received first byte
        .rx_db_en_o (icd_rx_db),     // flag: received next byte
        // Send data
        .tx_byte_i (icd_tx_byte),      // transmit byte
        .tx_en_i (icd_tx_en)         // flag: catch the transmit byte
    );

    icd_controller icdctrl (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // ICD-SPI_Slave Received data
        .rx_byte_i (icd_rx_byte),     // received byte data
        .rx_hdr_en_i (icd_rx_hdr),    // flag: received first byte
        .rx_db_en_i (icd_rx_db),     // flag: received next byte
        // ICD-SPI_Slave Send data
        .tx_byte_o (icd_tx_byte),      // transmit byte
        .tx_en_o (icd_tx_en),         // flag: catch the transmit byte

        // NORA master interface - internal debug controller
        .nora_mst_addr_o (nora_mst_addr),
        .nora_mst_data_o (nora_mst_datawr),
        .nora_mst_datard_i (nora_mst_datard),
        // output          nora_mst_datard_valid,      // flags nora_mst_datard_o to be valid
        .nora_mst_ack_i (nora_mst_ack),                 // end of access, also nora_mst_datard_o is valid now.
        // .nora_mst_req_BOOTROM_o (nora_mst_req_BOOTROM),
        // .nora_mst_req_BANKREG_o (nora_mst_req_BANKREG),
        // .nora_mst_req_SCRB_o (nora_mst_req_SCRB),
        .nora_mst_req_SRAM_o (nora_mst_req_SRAM),
        .nora_mst_req_OTHER_o (nora_mst_req_OTHER),
        // .nora_mst_req_VIA_o (nora_mst_req_VIA),
        // .nora_mst_req_VERA_o (nora_mst_req_VERA),
        .nora_mst_rwn_o (nora_mst_rwn),
        // CPU control
        .run_cpu (icd_run_cpu),
        .stopped_cpu (stopped_cpu),
        .cpu_force_resn_o (icd_cpu_force_resn),
        // Trace input
        .cpubus_trace_i (cpubus_trace),
        .trace_catch_i (release_wr)
    );


    /**
    * External CPU and Memory Bus controller
    */
    bus_controller busctrl0 (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // CPU bus signals - address and data
        .cpu_db_o (cpu_db_o),           // output to cpu data bus
        .cpu_db_i (CD),
        .cpu_abh_i (CA),
        // CPU bus control
        .cpu_be_o (CBE),
        .cpu_sync_vpa_i (CSYNC_VPA),
        .cpu_vpu_i (CVPn),
        .cpu_vda_i (CVDA),
        .cpu_cef_i (CEF),
        .cpu_rw_i (CRWn),
        // Memory bus address and data signals
        .mem_abh_o (MAH),      // memory address high bits 12-20: private to FPGA = output
        .memcpu_abl_o (mem_abl_o),      // memory address low bits 0-11: shared with CPU = bidi
        .memcpu_abl_i (MAL),
        .mem_db_i (MD),           // input from memory data bus (ext)
        .mem_db_o (mem_db_o),           // output to memory data bus (ext)
        // memory bus control signals - external devices
        .mem_rdn_o (MRDn),            // Memory Read external
        .mem_wrn_o (MWRn),            // Memory Write external
        .sram_csn_o (M1CSn),           // SRAM chip-select
        // .via_csn_o (VIACS),             // VIA chip-select
        .vera_csn_o (VCS0n),              // VERA chip-select
        .aura_csn_o (VCS1n),
        .enet_csn_o (VCS2n),
        // Phaser for CPU clock
        .setup_cs (setup_cs),
        .release_wr (release_wr),
        .release_cs (release_cs),
        .run_cpu (busct_run_cpu),
        .stopped_cpu (stopped_cpu),
        //.stretching_viaphi (open),      // TBD!!!
        // NORA master interface - internal debug controller
        .nora_mst_addr_i (nora_mst_addr),
        .nora_mst_data_i (nora_mst_datawr),
        .nora_mst_datard_o (nora_mst_datard),
        // output          nora_mst_datard_valid,      // flags nora_mst_datard_o to be valid
        .nora_mst_ack_o (nora_mst_ack),                 // end of access, also nora_mst_datard_o is valid now.
        // .nora_mst_req_BOOTROM_i (nora_mst_req_BOOTROM),
        // .nora_mst_req_BANKREG_i (nora_mst_req_BANKREG),
        // .nora_mst_req_SCRB_i (nora_mst_req_SCRB),
        .nora_mst_req_SRAM_i (nora_mst_req_SRAM),
        .nora_mst_req_OTHER_i (nora_mst_req_OTHER),
        // .nora_mst_req_VIA_i (nora_mst_req_VIA),
        // .nora_mst_req_VERA_i (nora_mst_req_VERA),
        .nora_mst_rwn_i (nora_mst_rwn),
        // NORA slave interface - internal devices
        .nora_slv_addr_o (nora_slv_addr),
        .nora_slv_datawr_o (nora_slv_datawr),     // write data = available just at the end of cycle!!
        .nora_slv_datawr_valid (nora_slv_datawr_valid),      // flags nora_slv_datawr_o to be valid
        .nora_slv_data_i (nora_slv_datard),
        .nora_slv_req_BOOTROM_o (nora_slv_req_BOOTROM),
        .nora_slv_req_SCRB_o (nora_slv_req_SCRB),
        .nora_slv_req_VIA1_o (nora_slv_req_VIA1),
        .nora_slv_rwn_o (nora_slv_rwn),
        // Bank parameters from SCRB
        .rambank_mask_i (rambank_mask)
        // // Trace output
        // .cpubus_trace_o (cpubus_trace),
        // .trace_catch_o (trace_catch)
    );

    // signals for VIA1
    wire [7:0] via1_slv_datard;
    wire [7:0] via1_gpio_ora;          // ORA = output reg A
    wire [7:0] via1_gpio_orb;
    wire [7:0] via1_gpio_ira;           // IRA = input reg A
    wire [7:0] via1_gpio_irb;
    wire [7:0] via1_gpio_ddra;         // DDRA = data direction reg A; 0 = input, 1 = output.
    wire [7:0] via1_gpio_ddrb;

    /**
    * Simplified VIA (65C22) - provides basic GPIO and Timer service.
    */
    simple_via via1 (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // NORA slave interface - internal devices
        .slv_addr_i (nora_slv_addr[3:0]),
        .slv_datawr_i (nora_slv_datawr),     // write data = available just at the end of cycle!!
        .slv_datawr_valid (nora_slv_datawr_valid),      // flags nora_slv_datawr_o to be valid
        .slv_datard_o (via1_slv_datard),
        .slv_req_i (nora_slv_req_VIA1),
        .slv_rwn_i (nora_slv_rwn),
        // GPIO interface, 2x 8-bit
        .gpio_ora (via1_gpio_ora),          // ORA = output reg A
        .gpio_orb (via1_gpio_orb),
        .gpio_ira (via1_gpio_ira),           // IRA = input reg A
        .gpio_irb (via1_gpio_irb),
        .gpio_ddra (via1_gpio_ddra),         // DDRA = data direction reg A; 0 = input, 1 = output.
        .gpio_ddrb (via1_gpio_ddrb),
        //
        .phi2 (CPHI2)
    );

    wire smc_i2csda_dr0;
    wire i2csda_dr0 = ((via1_gpio_ddra[0]) ? ~via1_gpio_ora[0] : 1'b0) | smc_i2csda_dr0;
    assign via1_gpio_ira = { NESDATA0, NESDATA1, 1'b1, 1'b1, NESCLOCK, NESLATCH, I2C_SCL, I2C_SDA };
    assign via1_gpio_irb = { 6'b110000, CPULED1, CPULED0 };
    assign NESCLOCK = (via1_gpio_ddra[3]) ? via1_gpio_ora[3] : 1'b0;
    assign NESLATCH = (via1_gpio_ddra[2]) ? via1_gpio_ora[2] : 1'b0;
    assign I2C_SCL = (via1_gpio_ddra[1]) ? via1_gpio_ora[1] : 1'bZ;
    // assign I2C_SDA = (via1_gpio_ddra[0]) ? via1_gpio_ora[0] : 1'bZ;
    assign I2C_SDA = (i2csda_dr0) ? 1'b0 : 1'bZ;

    assign CPULED0 = (via1_gpio_ddrb[0]) ? via1_gpio_orb[0] : blinkerled;
    assign CPULED1 = (via1_gpio_ddrb[1]) ? via1_gpio_orb[1] : 1'b1;


// CPU interface
    // put CPU data bus in Hi-Z as soon as RWB goes low (CPU is outputting write data)
    //                   CRWn=1     CRWn=0
    assign CD = (CRWn) ? cpu_db_o : 8'bZZZZZZZZ;

    // put Memory data bus in Hi-Z as soon as MRd goes low (SRAM is outputing read data)
    //                   MRDn=1     MRDn=0
    assign MD = (MRDn) ? mem_db_o : 8'bZZZZZZZZ;

    // put Memory address bus low in Hi-Z as soon as CPU bus drivers are active
    //                    CBE=1        CBE=0
    assign MAL = (CBE) ? 12'bZZZZZZZZZZZZ : mem_abl_o;


    assign CRESn = icd_cpu_force_resn;           // CPU reset
    assign CIRQn = VIRQn;           // CPU IRQ request
    assign CNMIn = 1'b1;           // CPU NMI request
    assign CABORTn = 1'b1;         // CPU ABORT request (16b only)
    assign CRDY = 1'bZ;             // CPU ready signal
    assign CSOB_MX = 1'bZ;          // CPU SOB (set overflow - 8b) / MX (16b)

    assign FMOSI = ~FMISO;
    assign FSCK = clk6x;
    assign FLASHCSn = 1;

    assign ph_run_cpu = busct_run_cpu && icd_run_cpu;

    // assign PS2K_CLKDR = 1'b0;
    // assign PS2K_DATADR = 1'b0;
    assign PS2M_CLKDR = 1'b0;
    assign PS2M_DATADR = 1'b0;

    // always @( posedge clk6x )
    // begin
    //     run_cpu <= 0;
    // end

    // System Management Controller
    smc smc1
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // I2C bus
        .I2C_SDA_i (I2C_SDA),
        .I2C_SDADR0_o (smc_i2csda_dr0),
        .I2C_SCL_i (I2C_SCL),
        // PS2 Keyboard port
        .PS2K_CLK (PS2K_CLK),
        .PS2K_DATA (PS2K_DATA),
        .PS2K_CLKDR (PS2K_CLKDR),
        .PS2K_DATADR (PS2K_DATADR)
    );

    assign nora_slv_datard = via1_slv_datard;
    // assign nora_slv_datard = (nora_slv_req_SCRB) ? ps2k_code : via1_slv_datard;

endmodule
