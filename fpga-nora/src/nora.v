/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/* NORA FPGA top */
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
    output CABORTn,         // CPU ABORT request (65816 only)
    output CPHI2,           // CPU clock
    output CBE,             // CPU bus-enable

    inout CRDY,             // CPU ready signal
    input CSOB_MX,          // CPU SOB (set overflow - 6502) / MX (65816)

    input CSYNC_VPA,        // CPU SYNC (6502) / VPA (65816) signal
    input CMLn,             // CPU memory lock
    input CVPn,             // CPU vector pull signal
    input CVDA,             // CPU VDA (65816 only)
    input CEF,              // CPU EF (65816 only)
    input CRWn,             // CPU R/W signal


// Memory bus
    output [20:12] MAH,      // memory address 9 high bits 12-20: private to FPGA = output
    inout [11:0] MAL,      // memory address low bits 0-11: shared with CPU = bidi
    inout [7:0] MD,         // Memory data bus
    output M1CSn,           // SRAM chip-select
    output MRDn,            // Memory Read
    output MWRn,            // Memory Write

// VIA interface
    // output VIAPHI2,         // TBD remove
    // output VIACS,           // TBD remove
    // input VIAIRQ,           // TBD remove
    output PERIRESn,        // TBD maybe remove

    inout I2C_SCL,
    inout I2C_SDA,

    output NESLATCH,
    output NESCLOCK,
    input NESDATA1,
    input NESDATA0,

    output CPULED0,
    output CPULED1,

// additional ILI SPI ports
    output ILICSn,      // TBD remove
    output ILIDC,       // TBD remove
    output TCSn,        // TBD remove

    input CPUTYPE02,        // board assembly CPU type: 0 => 65C816 (16b), 1 => 65C02 (8b)

// PS2 ports
    inout PS2K_CLK,
    inout PS2K_DATA,
    output PS2K_CLKDR,      // TBD remove
    output PS2K_DATADR,     // TBD remove
    
    inout PS2M_CLK,         // via bidi level-shifter
    inout PS2M_DATA,        // via bidi level-shifter
    output PS2M_CLKDR,      // not used on the PCB
    output PS2M_DATADR,     // not used on the PCB

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

    output AUDIO_DATA,          // was: VAUX0
    output AUDIO_BCK,           // was: VAUX1
    output AUDIO_LRCK,          // was: VAUX2

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
// IMPLEMENTATION
    wire clk6x;
    wire clk6x_locked;
    wire rst_req;
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
        .clk (clk6x), .clklocked (clk6x_locked), .rstreq(rst_req),
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
    wire  latch_ad;     // address bus shall be registered; also, in the 24-bit mode, latch the upper 8b on the data bus
    wire  setup_cs;   // (catch CPU address and) setup the CSx signals
    wire  release_wr;  // release write signal now, to have a hold before the cs-release
    wire  release_cs;  // CPU access is complete, release the CS

    /* 
    * Phaser generates CPU phased clock CPHI2
    * and supporting signals for control of the cpu and memory bus.
    */
    phaser ph0 ( 
        .clk  (clk6x),
        .resetn   (resetn),
        .run    (ph_run_cpu),
        .stopped (stopped_cpu),
        .cphi2  (CPHI2),
        .latch_ad  (latch_ad),
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
    wire            nora_slv_req_OPM;
    wire            nora_slv_rwn;
    // Bank parameters from SCRB
    // wire    [7:0]   rambank_mask = 8'hFF;
    wire    [7:0]   rambank_mask; // = 8'h7F;       // X16 compatibility: allow only 128 RAM banks after reset

    // CPU address bus -virtual internal `input' signal
    // create the 16-bit CPU bus address by concatenating the two bus signals
    wire [15:0]     cpu_ab = { CA, MAL };
    reg [15:0]      cpu_ab_r;
    reg [7:0]       cba_r;
    reg             csob_m_r, csob_x_r, csync_vpa_r, cmln_r, cvpn_r, cvda_r, cef_r, crwn_r;
    reg             cputype02_r;            // board assembly: 0 => 65C816, 1 => 65C02.

    // sample address and CPU status outputs for trace buffer at latch_ad
    always @(posedge clk6x)
    begin
        if (latch_ad)               // PHY2 rising
        begin
            cpu_ab_r <= cpu_ab;
            
            if (cputype02_r)
                cba_r <= 8'h00;           // fixed bank address 0 in 65C02
            else
                cba_r <= CD;            // 65C816 on PHI2 rising edge.
            
            csob_x_r <= CSOB_MX | cputype02_r | CEF;       // 6502: Set Overflow Bit; 65816: M/X status flag; (Flag M is valid during PHI2 negative transition 
                                        // and Flag X is valid during PHI2 positive transition. 0=>16-bit, 1=8-bit)
                                        // In Emulation mode (CEF=1), force 1 to indicate 8-bit register width.
            csync_vpa_r <= CSYNC_VPA;   // 6502: SYNC, 65816: Valid Program Address
            cmln_r <= CMLn;         // memory lock, active low
            cvpn_r <= CVPn;         // vector pull, active low.
            cvda_r <= CVDA | cputype02_r;         // Valid Data Addres (65C816 only; for C02, we always set 1)
            cef_r <= CEF | cputype02_r;           // emulation flag (1=6502, 0=native 16b)
            crwn_r <= CRWn;
        end

        if (release_wr)
        begin
            csob_m_r <= CSOB_MX | cputype02_r | cef_r;       // 6502: Set Overflow Bit; 65816: M/X status flag; (Flag M is valid during PHI2 negative transition 
                                        // and Flag X is valid during PHI2 positive transition.)
                                        // In Emulation mode (CEF=1), force 1 to indicate 8-bit register width.
        end

        cputype02_r <= CPUTYPE02;
    end

    localparam  CPUTRACE_WIDTH = 48 + 8;

    // Trace signal
    wire [CPUTRACE_WIDTH-1:0]   cpubus_trace = {
        // trace bytes [6]
            cba_r,              // CPU bank address
        // trace bytes [5]
            MAH[20:13],         // top 8 bits on the memory bus
        // trace bytes [4], [3]:
            cpu_ab_r,        // CPU address bus, [15:12][11:0] = 16b
        // trace byte [2]:
            CD,             // CPU data bus, 8b
        // trace byte [1]:
            3'b000,
            csob_x_r,           // 6502: CPU SOB (set overflow - 8b); 65816: X-flag (16b)
            CRESn,           // CPU reset
            CIRQn,           // CPU IRQ request
            CNMIn,           // CPU NMI request
            CABORTn,         // CPU ABORT request (16b only)
        // trace byte [0]:
            CRDY,             // CPU ready signal
            csob_m_r,           // 6502: CPU SOB (set overflow - 8b); 65816: M-flag (16b)
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
    wire      cpu_force_irqn;       // 0 will force CPU IRQ
    wire      cpu_force_nmin;       // 0 will force CPU NMI
    wire      cpu_force_abortn;       // 0 will force CPU ABORT (16b only)
    wire      cpu_block_irq;       // 1 will block CPU IRQ
    wire      cpu_block_nmi;       // 1 will block CPU NMI
    wire      cpu_block_abort;       // 1 will block CPU ABORT

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

    icd_controller #( .CPUTRACE_WIDTH (CPUTRACE_WIDTH), .CPUTRACE_DEPTH(8) ) 
    icdctrl (
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
        //
        .cpu_force_resn_o (icd_cpu_force_resn),
        .cpu_force_irqn_o (cpu_force_irqn),       // 0 will force CPU IRQ
        .cpu_force_nmin_o (cpu_force_nmin),       // 0 will force CPU NMI
        .cpu_force_abortn_o (cpu_force_abortn),       // 0 will force CPU ABORT (16b only)
        .cpu_block_irq_o (cpu_block_irq),       // 1 will block CPU IRQ
        .cpu_block_nmi_o (cpu_block_nmi),       // 1 will block CPU NMI
        .cpu_block_abort_o (cpu_block_abort),       // 1 will block CPU ABORT
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
        .cputype02_i (cputype02_r),
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
        .aio_csn_o (VCS1n),
        .enet_csn_o (VCS2n),
        // Phaser for CPU clock
        .setup_cs (setup_cs),
        .release_wr (release_wr),
        .release_cs (release_cs),
        .run_cpu (busct_run_cpu),
        .stopped_cpu (stopped_cpu),
        //.stretch_cphi (open),      // TBD!!!
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
        .nora_slv_req_OPM_o (nora_slv_req_OPM),
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
    assign via1_gpio_ira = { NESDATA0, NESDATA1, 1'b1, 1'b1, ~NESCLOCK, ~NESLATCH, I2C_SCL, I2C_SDA };
    assign via1_gpio_irb = { 6'b110000, CPULED1, CPULED0 };
    assign NESCLOCK = ((via1_gpio_ddra[3]) ? ~via1_gpio_ora[3] : 1'b1);
    assign NESLATCH = ((via1_gpio_ddra[2]) ? ~via1_gpio_ora[2] : 1'b1);
    assign I2C_SCL = (via1_gpio_ddra[1]) ? via1_gpio_ora[1] : 1'bZ;
    // assign I2C_SDA = (via1_gpio_ddra[0]) ? via1_gpio_ora[0] : 1'bZ;
    assign I2C_SDA = (i2csda_dr0) ? 1'b0 : 1'bZ;

    assign CPULED0 = (via1_gpio_ddrb[0]) ? via1_gpio_orb[0] : blinkerled;
    assign CPULED1 = (via1_gpio_ddrb[1]) ? via1_gpio_orb[1] : 1'b1;


// CPU interface
    // Note: CPU READS => CRWn=1
    // Note: CPU WRITES => CRWn=0
    //
    // Put CPU data bus in Hi-Z as soon as RWB goes low (CPU is outputting write data).
    // I.E. Allow driving CD from NORA only iff CRWn=1 (CPU reads) and CPHI2=1 (second phase - necessary for '816)
    //                                            CPU_READ   CPU_WRITE
    assign CD = (CRWn && (CPHI2 || (release_cs && clk6x))) ? cpu_db_o : 8'bZZZZZZZZ;

    // create a 1T delayed MRDn  
    reg    mrdn_delayed;

    always @(posedge clk6x) mrdn_delayed <= MRDn;

    // put Memory data bus in Hi-Z as soon as MRd goes low (SRAM is outputing read data)
    // put to driving state with 1T delay to allow bus turn-around time.
    //                                  MRDn=1     MRDn=0
    assign MD = (MRDn && mrdn_delayed) ? mem_db_o : 8'bZZZZZZZZ;

    // put Memory address bus low in Hi-Z as soon as CPU bus drivers are active
    //                    CBE=1        CBE=0
    assign MAL = (CBE) ? 12'bZZZZZZZZZZZZ : mem_abl_o;

    wire  nmi_req_n;

    assign CRESn = icd_cpu_force_resn;           // CPU reset
    assign CIRQn = (VIRQn & cpu_force_irqn) | cpu_block_irq;           // CPU IRQ request
    assign CNMIn = (nmi_req_n & cpu_force_nmin) | cpu_block_nmi;           // CPU NMI request
    assign CABORTn = cpu_force_abortn | cpu_block_abort;         // CPU ABORT request (16b only)
    assign CRDY = 1'bZ;             // CPU ready signal (output)
    // assign CSOB_MX = 1'bZ;          // CPU SOB (set overflow - 8b) / MX (16b)

    // enable phaser to run the CPU?
    assign ph_run_cpu = busct_run_cpu && icd_run_cpu;

    assign PS2M_CLKDR = 1'b0;           // unused
    assign PS2M_DATADR = 1'b0;          // unused
    // PS2 Mouse port: drive ctrl signals
    wire ps2m_clkdr0;
    wire ps2m_datadr0;
    // PS2 Keyboard port: drive ctrl signals
    wire ps2k_clkdr0;
    wire ps2k_datadr0;

    assign PS2K_CLKDR = ps2k_clkdr0;            // unused on the 2nd board
    assign PS2K_DATADR = ps2k_datadr0;          // unused on the 2nd board

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
        .PS2K_CLKDR (ps2k_clkdr0),
        .PS2K_DATADR (ps2k_datadr0),
        // PS2 Mouse port
        .PS2M_CLK (PS2M_CLK),
        .PS2M_DATA (PS2M_DATA),
        .PS2M_CLKDR0 (ps2m_clkdr0),
        .PS2M_DATADR0 (ps2m_datadr0)

    );

    // PS2 Mouse port: generate output signal: 0 or HiZ
    assign PS2M_CLK = (ps2m_clkdr0) ? 1'b0 : 1'bZ;
    assign PS2M_DATA = (ps2m_datadr0) ? 1'b0 : 1'bZ;

    // PS2 Keyboard port: generate output signal: 0 or HiZ
    // HACK: just on the 2nd ('816) board
    assign PS2K_CLK = (ps2k_clkdr0 && !cputype02_r) ? 1'b0 : 1'bZ;
    assign PS2K_DATA = (ps2k_datadr0 && !cputype02_r) ? 1'b0 : 1'bZ;

    // read data from BOOTROM
    wire [7:0]  bootrom_slv_datard;

    // boot rom
    bootrom btrom
    (
        // Global signals
        .clk (clk6x),        // 48MHz
        .resetn (resetn),     // sync reset
        // NORA slave interface - internal devices
        .slv_addr_i (nora_slv_addr[8:0]),
        .slv_datawr_i (nora_slv_datawr),     // write data = available just at the end of cycle!!
        .slv_datawr_valid (nora_slv_datawr_valid),      // flags nora_slv_datawr_o to be valid
        .slv_datard_o (bootrom_slv_datard),       // read data
        .slv_req_i (nora_slv_req_BOOTROM),          // request (chip select)
        .slv_rwn_i (nora_slv_rwn)           // read=1, write=0
    );


    // SPI MASTER AND HOST CONTROLLER
    wire [7:0]    spireg_dr;            // read data output from the core (from the CONTROL or DATA REG)
    wire  [7:0]    spireg_dw;            // write data input to the core (to the CONTROL or DATA REG)
    wire          spireg_wr;           // write signal
    wire          spireg_rd;           // read signal
    wire          spireg_ad;           // target register select: 0=CONTROL REG, 1=DATA REG.

    spi_master_hostctrl
    #(
        .NUM_TARGETS (1),                // number of supported targets (slaves), min 1.
        .RXFIFO_DEPTH_BITS (4),
        .TXFIFO_DEPTH_BITS (4)
    ) spimhstc (
        // Global signals
        .clk (clk6x),                    // 48MHz
        .resetn (resetn),                 // sync reset
        //
        // SPI Master Peripheral signals
        .spi_clk_o (FSCK),
        .spi_csn_o (FLASHCSn),           // active low
        .spi_mosi_o (FMOSI),
        .spi_mosi_drive_o (),
        .spi_miso_i (FMISO),
        //
        // REGISTER INTERFACE
        .reg_d_o (spireg_dr),            // read data output from the core (from the CONTROL or DATA REG)
        .reg_d_i (spireg_dw),            // write data input to the core (to the CONTROL or DATA REG)
        .reg_wr_i (spireg_wr),           // write signal
        .reg_rd_i (spireg_rd),           // read signal
        .reg_ad_i (spireg_ad)            // target register select: 0=CONTROL REG, 1=DATA REG.
    );

    // SCRB output data
    wire [7:0] SCRB_slv_datard;

    // common system registers
    sysregs scrb (
        // Global signals
        .clk (clk6x),                    // 48MHz
        .resetn (resetn),                 // sync reset
        // NORA SLAVE Interface
        .slv_addr_i (nora_slv_addr[4:0]),
        .slv_datawr_i (nora_slv_datawr),     // write data = available just at the end of cycle!!
        .slv_datawr_valid (nora_slv_datawr_valid),      // flags nora_slv_datawr_o to be valid
        .slv_datard_o (SCRB_slv_datard),       // read data
        .slv_req_i (nora_slv_req_SCRB),          // request (chip select)
        .slv_rwn_i (nora_slv_rwn),           // read=1, write=0
        //
        // RAMBANK_MASK
        .rambank_mask_o (rambank_mask),
        // SPI Master interface for accessing the flash memory
        .spireg_d_o (spireg_dw),            // read data output from the core (from the CONTROL or DATA REG)
        .spireg_d_i (spireg_dr),            // write data input to the core (to the CONTROL or DATA REG)
        .spireg_wr_i (spireg_wr),           // write signal
        .spireg_rd_i (spireg_rd),           // read signal
        .spireg_ad_i (spireg_ad)            // target register select: 0=CONTROL REG, 1=DATA REG.
    );

    // OPM output data
    wire [7:0]   OPM_slv_datard = 8'hFF;

`ifdef OPM_INTERNAL
    fm2151 opm
    (
        // Global signals
        .clk                (clk6x),      // 48MHz
        .resetn             (resetn),     // sync reset
        // Host interface (slave)
        .slv_addr_i         (nora_slv_addr[4:0]),
        .slv_datawr_i       (nora_slv_datawr),     // write data = available just at the end of cycle!!
        .slv_datawr_valid   (nora_slv_datawr_valid),      // flags nora_slv_datawr_o to be valid
        .slv_datard_o       (OPM_slv_datard),       // read data
        .slv_req_i          (nora_slv_req_OPM),          // request (chip select)
        .slv_rwn_i          (nora_slv_rwn),           // read=1, write=0
        .slv_irqn_o         ( ),         // interrupt output, active low
        // Sound output to the on-board DAC
        .audio_bck          (AUDIO_BCK),
        .audio_data         (AUDIO_DATA),
        .audio_lrck         (AUDIO_LRCK)
    );
`endif

    assign nora_slv_datard = (nora_slv_req_BOOTROM) ? bootrom_slv_datard : 
                            (nora_slv_req_SCRB) ? SCRB_slv_datard :
                            (nora_slv_req_VIA1) ? via1_slv_datard :
                            (nora_slv_req_OPM) ? OPM_slv_datard :
                            8'hFF;


    // handle the user ATTBTN
    attenbtn abtn
    (
        // Global signals
        .clk            (clk6x),        // 48MHz
        .resetn         (resetn),     // sync reset
        // User Button
        .attbtn_i       (ATTBTN),       // active-low button input
        // System Control output
        .nmi_req_no     (nmi_req_n),     // active-low NMI request output to the CPU
        .rst_req_o      (rst_req)       // active-high global reset request for the FPGA+CPU
    );



    // define unused output signals
    assign VIACS = 1'b1;
    assign UART_TX = 1'b1;
    assign UART_CTS = 1'b1;
    assign TCSn = 1'b1;
    assign PERIRESn = 1'b1;
    assign ILIDC = 1'b0;

    assign ILICSn = nora_slv_req_VIA1;          // for debug

endmodule
