/* Copyright (c) 2023-2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * External CPU and Memory Bus controller
 */
module bus_controller (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    input           cputype02_i,    // 0 => 65C816, 1 => 65C02.
    //
    // CPU bus signals - address and data
    output reg [7:0] cpu_db_o,           // output to cpu data bus
    input   [7:0]   cpu_db_i,
    input   [15:12] cpu_abh_i,
    // CPU bus control output
    output reg      cpu_be_o,           // CPU Bus Enable (active high)
    // CPU bus status input
    input           cpu_sync_vpa_i,     // 65C02: SYNC, 65C816: VPA (Valid Program Address)
    input           cpu_vpu_i,          // Vector Pull (active low!)
    input           cpu_vda_i,          // 65C816: Valid Data Address
    input           cpu_cef_i,          // 65C816: C/E flag
    input           cpu_rw_i,           // CPU read (1) / write (0)
    // Memory bus address and data signals
    output reg [20:12] mem_abh_o,      // memory address high bits 12-20: private to FPGA = output
    output reg [11:0]  memcpu_abl_o,      // memory address low bits 0-11: shared with CPU = bidi
    input   [11:0]  memcpu_abl_i,
    input   [7:0]   mem_db_i,           // input from memory data bus (ext)
    output  [7:0]   mem_db_o,           // output to memory data bus (ext)
    // memory bus control signals - external devices
    output reg      mem_rdn_o,            // Memory Read external
    output reg      mem_wrn_o,            // Memory Write external
    output reg      sram_csn_o,           // SRAM chip-select
    output reg      vera_csn_o,              // VERA chip-select
    output reg      aio_csn_o,             // AURA and IO chip-select
    output reg      enet_csn_o,             // e-net LAN chip-select
    //
    // Phaser for CPU clock: phase status inputs
    input           setup_cs,
    input           release_wr,
    input           release_cs,
    input           cphi2_i,
    // Phase CPU clock control i/o
    output reg      run_cpu,
    input           stopped_cpu,
    output reg [1:0] s4_ext_o,       // extend the S4H cycle by additional clk cycles
    //
    // NORA master interface (sink) - addressing from the internal debug controller.
    //      Any access from the master interface will pause the CPU in the S1L state
    //      before servicing the master request.
    input   [23:0]  nora_mst_addr_i,            // 24-bit master request address 
    input   [7:0]   nora_mst_data_i,            // master write data in
    output reg [7:0] nora_mst_datard_o,         // master read data out
    output reg      nora_mst_ack_o,                 // end of access, also nora_mst_datard_o is valid now.
    input           nora_mst_req_SRAM_i,        // master request to SRAM
    input           nora_mst_req_OTHER_i,       // master request to all other devices:
                                                //   nora_mst_addr_i[19]  => to BANKREGS
                                                //   nora_mst_addr_i[18]  => to IOREGS
    input           nora_mst_rwn_i,             // master is reading (1) or writing (0)
    //
    // NORA slave interface (source) - addressing to internal devices implemented inside of NORA
    output reg [15:0]  nora_slv_addr_o,         // requested 16-bit slave address
    output  [7:0]   nora_slv_datawr_o,          // write data = available just at the end of cycle!!
    output          nora_slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    input   [7:0]   nora_slv_data_i,            // read data from slave
    output reg      nora_slv_req_BOOTROM_o,     // a request to internal BOOTROM (PBL)
    output reg      nora_slv_req_SCRB_o,        // a request to the SCRB at 0x9F50
    output reg      nora_slv_req_VIA1_o,        // a request to VIA1 at 0x9F00
    output reg      nora_slv_req_VIA2_o,        // a request to VIA2 at 0x9F10
    output reg      nora_slv_req_OPM_o,         // a request to internal OPM
    output reg      nora_slv_rwn_o,             // reading (1) or writing (0) to the slave
    //
    // Bank parameters from SCRB
    input [7:0]     rambank_mask_i         // CPU accesses using RAMBANK reg are limited to this range
);
//// IMPLEMENTATION ////

    localparam HIGH_INACTIVE = 1'b1;
    localparam HIGH_ACTIVE = 1'b1;
    localparam LOW_ACTIVE = 1'b0;
    localparam LOW_INACTIVE = 1'b0;

    // Master Service FSM states
    localparam MST_IDLE = 3'o0;                 // no master request, normal CPU runs
    localparam MST_WAIT_CPU_STOP = 3'o1;        // waiting for CPU to be stopped in S1L by phaser
    localparam MST_DISABLE_CPU_BUS = 3'o2;      // disabling the CPU bus (BE=0)
    localparam MST_SETUP_ACC = 3'o3;            // setting up the access on the bus
    localparam MST_EXT_ACC = 3'o4;              // access cycle
    localparam MST_EXT_ACC2 = 3'o5;             // access cycle
    localparam MST_DATA_ACC = 3'o6;             // data access cycle: read/write data is valid
    localparam MST_FIN_ACC = 3'o7;              // end of master access, deasserting.

    // master request state machine
    reg [2:0]       mst_state;


    // CPU address bus -virtual internal `input' signal
    // create the 16-bit CPU bus address by concatenating the two bus signals
    wire [15:0]     cpu_ab_i = { cpu_abh_i, memcpu_abl_i };

    reg [7:0]       cba_r;          // CPU Bank Address (65C816)

    reg             mem_wrn_adv1_r;      // 1T-advanced memory write (mem_wrn_o)
    reg             mem_wrn_adv2_r;      // 2T-advanced memory write (mem_wrn_o)

    // aggregated master request
    wire nora_mst_req = nora_mst_req_OTHER_i | nora_mst_req_SRAM_i;

    wire nora_mst_req_OTHER_BOOTROM_i = nora_mst_req_OTHER_i && nora_mst_addr_i[20];
    wire nora_mst_req_OTHER_BANKREG_i = nora_mst_req_OTHER_i && nora_mst_addr_i[19];
    wire nora_mst_req_OTHER_IOREGS = nora_mst_req_OTHER_i && nora_mst_addr_i[18];
    // wire nora_mst_req_OTHER_SCRB_i = nora_mst_req_OTHER_i && nora_mst_addr_i[18];
    // wire nora_mst_req_OTHER_VERA_i = nora_mst_req_OTHER_i && nora_mst_addr_i[17];
    // wire nora_mst_req_OTHER_VIA_i = nora_mst_req_OTHER_i && nora_mst_addr_i[16];


    // Current Banks - remap
    reg   [7:0]   rambank_nr;
    reg   [7:0]   rambank_masked_nr;
    reg   [7:0]   romblock_nr;

    // BANKREGs are handled directly in this module
    reg         nora_slv_req_BANKREG;

    reg         nora_mst_driving_memdb;

    reg  [7:0]      cpu_db_hold_r;

    // set the memory data bus output signals:
    //  - if some of the nora's internal master (ICD) is accesing the bus, then it is driving directly.
    //  - otherwise, CPU is driving during PHI2=Hi (second half), and a bus-hold regfister during PHI2=Lo 
    //    (this is when the 65816 outputs CBA on its CPU data bus)
    assign mem_db_o = (nora_mst_driving_memdb) ? nora_mst_data_i 
                        : ( (cphi2_i) ? cpu_db_i : cpu_db_hold_r);

    /* Handling of CPU write data to a NORA slave: the problem is that the write
     * data is available on the CPU bus just at the end of bus cycle - PHI2 falling.
     * Imminent end of cycle is indicated by the release_wr flag.
     */
    assign nora_slv_datawr_o = (nora_mst_driving_memdb) ? nora_mst_data_i : cpu_db_i;                // pass CPU data write-through
    assign nora_slv_datawr_valid = release_wr || (mst_state == MST_DATA_ACC);


    always @( posedge clk6x )
    begin
        // trace_en_o <= 0;
        
        if (!resetn)
        begin   // sync reset
            // bus_state <= CPU_INITIAL;
            cpu_be_o <= HIGH_ACTIVE;
            mem_rdn_o <= HIGH_INACTIVE;
            mem_wrn_o <= HIGH_INACTIVE;
            mem_wrn_adv1_r <= HIGH_INACTIVE;
            mem_wrn_adv2_r <= HIGH_INACTIVE;
            sram_csn_o <= HIGH_INACTIVE;
            // via_csn_o <= HIGH_INACTIVE;
            vera_csn_o <= HIGH_INACTIVE;
            aio_csn_o <= HIGH_INACTIVE;
            enet_csn_o <= HIGH_INACTIVE;
            run_cpu <= 0;
            nora_mst_ack_o <= 0;
            nora_slv_req_BOOTROM_o <= 0;
            nora_slv_req_SCRB_o <= 0;
            nora_slv_req_VIA1_o <= 0;
            nora_slv_req_VIA2_o <= 0;
            nora_slv_req_OPM_o <= 0;
            cba_r <= 8'h00;
            rambank_nr <= 8'h00;
            romblock_nr <= 8'b1000_0000;        // rombank 128 - starts in BOOTROM
            // romblock_nr <= 6'b000000;        // rombank 0 - starts at 0x18_0000
            nora_slv_req_BANKREG <= 0;
            mst_state <= MST_IDLE;
            nora_mst_driving_memdb <= 0;
            s4_ext_o <= 2'b00;
        end else begin
            // By default, mem_wrn_o is 1T delayed version of mem_wrn_adv1_r,
            // unless wrn should be disabled (HIGH_INACTIVE) - then both regs are written immediately.
            mem_wrn_o <= mem_wrn_adv1_r;
            mem_wrn_adv1_r <= mem_wrn_adv2_r;

            if (setup_cs)
            begin
                // PHI2 is rising;
                // Load address from the CPU address bus and decode it
                memcpu_abl_o <= memcpu_abl_i;       // lower 12 bits are pass-through
                nora_slv_addr_o <= cpu_ab_i;
                nora_slv_rwn_o <= cpu_rw_i;
                s4_ext_o <= 2'b00;              // no cycle extension by default necessary

                if (cputype02_i)
                    cba_r <= 8'h00;           // fixed bank address 0 in 65C02
                else
                    cba_r <= cpu_db_i;            // 65C816 on PHI2 rising edge.

                // Check if CPU bus address is valid?
                // hint: in 65C02 the bus address is always valid.
                if (!cputype02_i && !cpu_vda_i && !cpu_sync_vpa_i)
                begin
                    // CPU == 65C816 and invalid bus address
                    // ==> No access is generated!
                    mem_rdn_o <= HIGH_INACTIVE;
                    mem_wrn_o <= HIGH_INACTIVE;
                    mem_wrn_adv1_r <= HIGH_INACTIVE;
                    mem_wrn_adv2_r <= HIGH_INACTIVE;
                    // and skip the rest of decoding.
                end
                // Allowed to decode CPU address space regions;
                else if (cputype02_i || (cpu_db_i == 8'h00))
                begin
                    // is 65c02 (16-bit), or zero bank of 65c816.
                    // Decoding inside of CPU Bank 0x00:
                    if (cpu_ab_i[15:1] == 15'b000000000000000)
                    begin
                        // registers 0x0000 RAMBANK and 0x0001 ROMBANK
                        nora_slv_req_BANKREG <= 1;
                    end
                    else if (cpu_abh_i[15:14] == 2'b11)
                    begin
                        // CPU address 0xC000 - 0xF000 => 32x 16k ROM pages mapped at SRAM pages 64 to 127;
                        if (romblock_nr[7] == 1'b1)
                        begin
                            // special PBL ROM bank is inside of FPGA
                            nora_slv_req_BOOTROM_o <= 1;
                            // NOTE: when BOOTROM is selected as the ROMBANK, 
                            // then Vector Pull always happens inside it, and not from
                            // the rombank 0 !!
                            mem_abh_o <= 9'h1FF;         // MAH=0x1FF is just a mark for the trace buffer, not a real address.
                        end else begin
                            // normal ROM bank in SRAM.
                            // Check if this is a Vector Pull cycle?
                            if (!cpu_vpu_i)
                            begin
                                // Vector Pull cycle (cpu_vpu_i is active low) -> must access the rombank 0x00 always!
                                mem_abh_o <= { 2'b01, 5'b00000, cpu_abh_i[13:12] };
                            end else begin
                                // normal access through the active rompage, starting at SRAM Page 64
                                mem_abh_o <= { 2'b01, romblock_nr[4:0], cpu_abh_i[13:12] };
                            end
                            sram_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~cpu_rw_i;
                            mem_wrn_o <= HIGH_INACTIVE;         // never allow writing to the ROM bank!
                            mem_wrn_adv1_r <= HIGH_INACTIVE;
                            mem_wrn_adv2_r <= HIGH_INACTIVE;
                        end
                    end 
                    else if (cpu_abh_i[15:13] == 3'b101)
                    begin
                        // CPU address 0xA000 - 0xB000 => 8k RAM Pages mapped from the middle of SRAM (MSB inverted)
                        mem_abh_o <= { rambank_masked_nr ^ 8'h80, cpu_abh_i[12] };
                        // mem_abh_o <= { rambank_nr & rambank_mask_i, cpu_abh_i[12] };
                        sram_csn_o <= LOW_ACTIVE;
                        mem_rdn_o <= ~cpu_rw_i;
                        mem_wrn_adv1_r <= cpu_rw_i;
                        mem_wrn_adv2_r <= cpu_rw_i;
                    end
                    else if (cpu_ab_i[15:8] == 8'h9F)
                    begin
                        //
                        // IO area at 0x9Fxx decoding from CPU address
                        //
                        if (cpu_ab_i[7:4] == 4'h0)
                        begin
                            // 0x9F00 VIA I/O controller #1
                            nora_slv_req_VIA1_o <= 1;
                        end 
                        else if (cpu_ab_i[7:4] == 4'h1)
                        begin
                            // 0x9F10 VIA I/O controller #2
                            nora_slv_req_VIA2_o <= 1;
                        end 
                        else if (cpu_ab_i[7:5] == 3'b001)
                        begin
                            // 0x9F20, 0x9F30 VERA video controller
                            vera_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~cpu_rw_i;
                            mem_wrn_adv2_r <= cpu_rw_i;         // advanced by 2T
                            s4_ext_o <= 2'b01;              // extend S4H by 1cc (add 20ns of access time)
                        end
                        else if (cpu_ab_i[7:4] == 4'h4)
                        begin
                            // 0x9F40-F AURA audio controller
    `ifdef OPM_INTERNAL
                            nora_slv_req_OPM_o <= 1;
    `else
                            aio_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~cpu_rw_i;
                            mem_wrn_adv1_r <= cpu_rw_i;
                            mem_wrn_adv2_r <= cpu_rw_i;
    `endif
                        end
                        else if ((cpu_ab_i[7:4] == 4'h5) || (cpu_ab_i[7:4] == 4'h6))
                        begin
                            // 0x9F50 NORA-SCRB
                            nora_slv_req_SCRB_o <= 1;
                        end
                        else if (cpu_ab_i[7:4] == 4'h8)
                        begin
                            // 0x9F80 ENET LAN controller
                            enet_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~cpu_rw_i;
                            mem_wrn_adv1_r <= cpu_rw_i;
                            mem_wrn_adv2_r <= cpu_rw_i;
                            s4_ext_o <= 2'b10;              // extend S4H by 2cc (add 40ns of access time)
                        end
                    end
                    else 
                    begin
                        // rest: base low memory of CPU mapped to SRAM pages 0-4
                        mem_abh_o <= { 5'h00, cpu_abh_i[15:12] };
                        sram_csn_o <= LOW_ACTIVE;
                        mem_rdn_o <= ~cpu_rw_i;
                        mem_wrn_adv1_r <= cpu_rw_i;
                        mem_wrn_adv2_r <= cpu_rw_i;
                    end
                end
                else begin
                    // 65c816 and CPU Bank != 0
                    // -> linear 24-bit address => SRAM access:
                    //              CPU Bank      CPU AddrHi
                    mem_abh_o <= { cpu_db_i[4:0], cpu_abh_i[15:12] };
                    sram_csn_o <= LOW_ACTIVE;
                    mem_rdn_o <= ~cpu_rw_i;
                    mem_wrn_adv1_r <= cpu_rw_i;
                    mem_wrn_adv2_r <= cpu_rw_i;
                end
            end
            
            // if (release_cs)
            // begin
            //     // end of a CPU cycle -> catch trace
            //     trace_catch_o <= 1;
            //     cpubus_trace_o <= { cpu_ab_i /*16b*/ , cpu_db_i /*8b*/, 
            //                         cpu_sync_vpa_i, cpu_vpu_i,
            //                         cpu_vda_i, cpu_cef_i, cpu_rw_i
            //                       };
            // end

            if (release_wr || (mst_state == MST_DATA_ACC))
            begin
                // write latch is sensitive: to have some hold time, release it now
                // before the CS gets released next.
                mem_wrn_o <= HIGH_INACTIVE;
                mem_wrn_adv1_r <= HIGH_INACTIVE;
                mem_wrn_adv2_r <= HIGH_INACTIVE;

                // perform the internal BANKREG slave operation
                if (nora_slv_req_BANKREG)
                begin
                    // request for BANKREGs access from the CPU - finishing;
                    // handle write data
                    if (!nora_slv_rwn_o)
                    begin
                        // writing
                        if (!nora_slv_addr_o[0])
                        begin
                            // 0x00 = RAMBLOCK
                            rambank_nr <= nora_slv_datawr_o; // & rambank_mask_i;
                        end else begin
                            // 0x01 = ROMBLOCK
                            romblock_nr <= nora_slv_datawr_o[7:0];
                        end
                    end
                end
            end

            if (release_cs || (mst_state == MST_FIN_ACC))
            begin
                // end of CPU or MST access;

                    // disable memorybus rd/wr flags
                mem_rdn_o <= HIGH_INACTIVE;
                mem_wrn_o <= HIGH_INACTIVE;
                mem_wrn_adv1_r <= HIGH_INACTIVE;
                mem_wrn_adv2_r <= HIGH_INACTIVE;
                    // disable all CS
                sram_csn_o <= HIGH_INACTIVE;
                // via_csn_o <= HIGH_INACTIVE;
                vera_csn_o <= HIGH_INACTIVE;
                aio_csn_o <= HIGH_INACTIVE;
                enet_csn_o <= HIGH_INACTIVE;
                nora_slv_req_BOOTROM_o <= 0;
                nora_slv_req_BANKREG <= 0;
                nora_slv_req_SCRB_o <= 0;
                nora_slv_req_VIA1_o <= 0;
                nora_slv_req_VIA2_o <= 0;
                nora_slv_req_OPM_o <= 0;
            end

            case (mst_state)
                MST_IDLE:
                begin
                    nora_mst_driving_memdb <= 0;
                    nora_mst_ack_o <= 0;
                    run_cpu <= 1;

                    // is (new) request?
                    if (nora_mst_req && !nora_mst_ack_o)        // prevent req start if ack still active!
                    begin
                        // CPU still runs (PHI2 togling)
                        // first stop the CPU:
                        run_cpu <= 0;
                        mst_state <= MST_WAIT_CPU_STOP;
                    end
                end

                MST_WAIT_CPU_STOP:
                begin
                    if (stopped_cpu)
                    begin
                        // the CPU has stopped.
                        // Set the address from master access on the external bus
                        mem_abh_o <= nora_mst_addr_i[20:12];
                        memcpu_abl_o <= nora_mst_addr_i[11:0];
                        nora_mst_driving_memdb <= 1;
                        // CPU bus still enabled => disable it.
                        cpu_be_o <= LOW_INACTIVE;
                        mst_state <= MST_DISABLE_CPU_BUS;
                    end
                end

                MST_DISABLE_CPU_BUS:
                begin
                    // empty cycle - just give some time for bus turnaround
                    mst_state <= MST_SETUP_ACC;
                end

                MST_SETUP_ACC:
                begin
                    // CPU stopped and its bus is disabled (HiZ).
                    // Realize the access! -> decode CS

                    nora_slv_addr_o <= nora_mst_addr_i[15:0];
                    nora_slv_rwn_o <= nora_mst_rwn_i;

                    if (nora_mst_req_SRAM_i)
                    begin
                        sram_csn_o <= LOW_ACTIVE;
                        mem_rdn_o <= ~nora_mst_rwn_i;
                        mem_wrn_adv1_r <= nora_mst_rwn_i;
                        mem_wrn_adv2_r <= nora_mst_rwn_i;
                    end

                    // if (nora_mst_req_OTHER_VIA_i)
                    // begin
                    //     via_csn_o <= LOW_ACTIVE;
                    // end

                    // if (nora_mst_req_OTHER_VERA_i)
                    // begin
                    //     vera_csn_o <= LOW_ACTIVE;
                    // end

                    if (nora_mst_req_OTHER_BOOTROM_i)
                    begin
                        nora_slv_req_BOOTROM_o <= 1;
                    end

                    if (nora_mst_req_OTHER_BANKREG_i)
                    begin
                        nora_slv_req_BANKREG <= 1;
                    end

                    // if (nora_mst_req_OTHER_SCRB_i)
                    // begin
                    //     nora_slv_req_SCRB_o <= 1;
                    // end

                    if (nora_mst_req_OTHER_IOREGS)
                    begin
                        // IOREGS area from ICD;
                        // decode address bits 7:0 just as from CPU to determine the final chip-select
                        //
                        if (nora_mst_addr_i[7:4] == 4'h0)
                        begin
                            // 0x9F00 VIA I/O controller #1
                            nora_slv_req_VIA1_o <= 1;
                        end 
                        else if (nora_mst_addr_i[7:4] == 4'h1)
                        begin
                            // 0x9F00 VIA I/O controller #2
                            nora_slv_req_VIA2_o <= 1;
                        end 
                        else if (nora_mst_addr_i[7:5] == 3'b001)
                        begin
                            // 0x9F20, 0x9F30 VERA video controller
                            vera_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~nora_mst_rwn_i;
                            mem_wrn_adv1_r <= nora_mst_rwn_i;
                            mem_wrn_adv2_r <= nora_mst_rwn_i;
                        end
                        else if (nora_mst_addr_i[7:4] == 4'h4)
                        begin
                            // 0x9F40 AURA audio controller
`ifdef OPM_INTERNAL
                            nora_slv_req_OPM_o <= 1;
`else
                            aio_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~nora_mst_rwn_i;
                            mem_wrn_adv1_r <= nora_mst_rwn_i;
                            mem_wrn_adv2_r <= nora_mst_rwn_i;
`endif
                        end
                        else if (nora_mst_addr_i[7:4] == 4'h5)
                        begin
                            // 0x9F50 NORA-SCRB
                            nora_slv_req_SCRB_o <= 1;
                        end
                        else if (nora_mst_addr_i[7:4] == 4'h8)
                        begin
                            // 0x9F80 ENET LAN controller
                            enet_csn_o <= LOW_ACTIVE;
                            mem_rdn_o <= ~nora_mst_rwn_i;
                            mem_wrn_adv1_r <= nora_mst_rwn_i;
                            mem_wrn_adv2_r <= nora_mst_rwn_i;
                        end
                    end

                    mst_state <= MST_EXT_ACC;
                end

                MST_EXT_ACC:
                begin
                    // empty cycle to allow for memory setup and access time
                    mst_state <= MST_EXT_ACC2;
                end

                MST_EXT_ACC2:
                begin
                    // empty cycle to allow for memory setup and access time
                    mst_state <= MST_DATA_ACC;
                end

                MST_DATA_ACC:
                begin
                    // Perform data i/o operation
                    // This is performed in addition to release_wr block above;
                    // if (nora_slv_req_BANKREG)
                    // begin
                    //     if (!nora_mst_addr_i[0])
                    //     begin
                    //         nora_mst_datard_o <= 8'h12; //rambank_nr;
                    //     end else begin
                    //         nora_mst_datard_o <= 8'h34; //{ 3'b000, romblock_nr };
                    //     end
                    // end else begin
                    nora_mst_datard_o <= cpu_db_o;          // read data is valid now!
                    // end
                    mst_state <= MST_FIN_ACC;
                end

                MST_FIN_ACC:
                begin
                    // Finalize master access.
                    // This is performed in addition to release_cs block above;
                    nora_mst_ack_o <= 1;                // signalize the end of master access
                    mst_state <= MST_IDLE;
                    nora_mst_driving_memdb <= 0;        // stop driving the memory bus
                    // enable CPU bus
                    cpu_be_o <= HIGH_ACTIVE;
                end


            endcase

            // DEBUG
            // enet_csn_o <= nora_slv_req_BANKREG;
        end
    end

    // generate data bus output to CPU
    always @( posedge clk6x )
    begin
        if (mem_rdn_o == LOW_ACTIVE)
        begin
            // ext Memory/Device reading
            cpu_db_o <= mem_db_i;
        end
        else if (nora_slv_req_BANKREG)
        begin
            // reading one of the bank registers
            if (!nora_slv_addr_o[0])
            begin
                // 0x00 = RAMBANK
                cpu_db_o <= rambank_nr;
            end else begin
                // 0x01 = ROMBANK
                cpu_db_o <= romblock_nr;
            end
        end
        else if (nora_slv_req_SCRB_o || nora_slv_req_VIA1_o || nora_slv_req_VIA2_o || nora_slv_req_BOOTROM_o || nora_slv_req_OPM_o)
        begin
            // internal slave reading
            cpu_db_o <= nora_slv_data_i;
        end

        // pre-compute the masked rambank
        rambank_masked_nr <= rambank_nr & rambank_mask_i;

        // Hold a valid CPU Data Bus value from the CPHI2=Hi state in a reg,
        // this is pushed to the memory bus during CPHI2=Low to provide additional hold time on writes
        // (The CPU 85C816 provides just about 10ns of hold time on data bus after CPHI2 falling).
        if (cphi2_i)
        begin
            cpu_db_hold_r <= cpu_db_i;
        end
    end
   

endmodule
