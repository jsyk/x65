/**
 * External CPU and Memory Bus controller
 */
module bus_controller (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // CPU bus signals - address and data
    output reg [7:0] cpu_db_o,           // output to cpu data bus
    input   [7:0]   cpu_db_i,
    input   [15:12] cpu_abh_i,
    // CPU bus control
    output reg      cpu_be_o,
    input           cpu_sync_vpa_i,
    input           cpu_vpu_i,
    input           cpu_vda_i,
    input           cpu_cef_i,
    input           cpu_rw_i,
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
    output reg      via_csn_o,             // VIA chip-select
    output reg      vera_csn_o,              // VERA chip-select
    output reg      vera1_csn_o,
    output reg      vera2_csn_o,
    // Phaser for CPU clock
    input           setup_cs,
    input           release_cs,
    output reg      run_cpu,
    input           stopped_cpu,
    output reg      stretching_viaphi,      // TBD!!!
    // NORA master interface - internal debug controller
    input   [23:0]  nora_mst_addr_i,
    input   [7:0]   nora_mst_data_i,
    output reg [7:0] nora_mst_datard_o,
    // output          nora_mst_datard_valid,      // flags nora_mst_datard_o to be valid
    output reg      nora_mst_ack_o,                 // end of access, also nora_mst_datard_o is valid now.
    // input           nora_mst_req_BOOTROM_i,
    // input           nora_mst_req_BANKREG_i,
    // input           nora_mst_req_SCRB_i,
    input           nora_mst_req_SRAM_i,
    input           nora_mst_req_OTHER_i,
    // input           nora_mst_req_VIA_i,
    // input           nora_mst_req_VERA_i,
    input           nora_mst_rwn_i,
    // NORA slave interface - internal devices
    output reg [15:0]  nora_slv_addr_o,
    output  [7:0]   nora_slv_datawr_o,     // write data = available just at the end of cycle!!
    output          nora_slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    input   [7:0]   nora_slv_data_i,
    output reg      nora_slv_req_BOOTROM_o,
    output reg      nora_slv_req_SCRB_o,
    output reg      nora_slv_rwn_o,
    // Bank parameters from SCRB
    input [7:0]     rambank_mask_i
);

    // state machine
    // parameter CPU_INITIAL = 3'o0;
    // parameter CPU_READING_NORA_SLAVE = 3'o1;
    // parameter CPU_READING_EXT_SLAVE = 3'o2;
    // parameter CPU_WRITING_NORA_SLAVE = 3'o3;
    // parameter CPU_WRITING_EXT_SLAVE = 3'o4;
    // parameter CPU_DISABLED_NORA_MASTER_READING = 3'o5;
    // parameter CPU_DISABLED_NORA_MASTER_WRITING = 3'o6;

    parameter HIGH_INACTIVE = 1'b1;
    parameter HIGH_ACTIVE = 1'b1;
    parameter LOW_ACTIVE = 1'b0;
    parameter LOW_INACTIVE = 1'b0;

    // reg  [2:0]      bus_state;

    parameter MST_IDLE = 3'o0;
    parameter MST_WAIT_CPU_STOP = 3'o1;
    parameter MST_DISABLE_CPU_BUS = 3'o2;
    parameter MST_SETUP_ACC = 3'o3;
    parameter MST_EXT_ACC = 3'o4;
    parameter MST_FIN_ACC = 3'o5;

    // master request state machine
    reg [2:0]       mst_state;


    // CPU address bus -virtual internal `input' signal
    // create the 16-bit CPU bus address by concatenating the two bus signals
    wire [15:0]     cpu_ab_i = { cpu_abh_i, memcpu_abl_i };

    // aggregated master request
    wire nora_mst_req = /*nora_mst_req_BOOTROM_i | nora_mst_req_BANKREG_i | nora_mst_req_SCRB_i */
                        nora_mst_req_OTHER_i
                        | nora_mst_req_SRAM_i /*| nora_mst_req_VIA_i | nora_mst_req_VERA_i*/;

    wire nora_mst_req_OTHER_BOOTROM_i = nora_mst_req_OTHER_i && nora_mst_addr_i[20];
    wire nora_mst_req_OTHER_BANKREG_i = nora_mst_req_OTHER_i && nora_mst_addr_i[19];
    wire nora_mst_req_OTHER_SCRB_i = nora_mst_req_OTHER_i && nora_mst_addr_i[18];
    wire nora_mst_req_OTHER_VERA_i = nora_mst_req_OTHER_i && nora_mst_addr_i[17];
    wire nora_mst_req_OTHER_VIA_i = nora_mst_req_OTHER_i && nora_mst_addr_i[16];


    // Current Banks - remap
    reg   [7:0]   rambank_nr;
    reg   [5:0]   rombank_nr;

    // BANKREGs are handled directly in this module
    reg         nora_slv_req_BANKREG;

    reg         nora_mst_driving_memdb;

    assign mem_db_o = (nora_mst_driving_memdb) ? nora_mst_data_i :  cpu_db_i;

    /* Handling of CPU write data to a NORA slave: the problem is that the write
     * data is available on the CPU bus just at the end of bus cycle.
     * End of cycle is indicated by the release_cs flag.
     */
    assign nora_slv_datawr_o = (nora_mst_driving_memdb) ? nora_mst_data_i : cpu_db_i;                // pass CPU data write-through
    assign nora_slv_datawr_valid = release_cs || nora_mst_ack_o;


    always @( posedge clk6x )
    begin
        if (!resetn)
        begin   // sync reset
            // bus_state <= CPU_INITIAL;
            cpu_be_o <= HIGH_ACTIVE;
            mem_rdn_o <= HIGH_INACTIVE;
            mem_wrn_o <= HIGH_INACTIVE;
            sram_csn_o <= HIGH_INACTIVE;
            via_csn_o <= HIGH_INACTIVE;
            vera_csn_o <= HIGH_INACTIVE;
            vera1_csn_o <= HIGH_INACTIVE;
            vera2_csn_o <= HIGH_INACTIVE;
            run_cpu <= 0;
            stretching_viaphi <= 0;
            nora_mst_ack_o <= 0;
            nora_slv_req_BOOTROM_o <= 0;
            nora_slv_req_SCRB_o <= 0;
            rambank_nr <= 0;
            rombank_nr <= 0;
            nora_slv_req_BANKREG <= 0;
            mst_state <= MST_IDLE;
            nora_mst_driving_memdb <= 0;
        end else begin
            if (setup_cs)
            begin
                // PHI2 is rising;
                // Load address from the CPU address bus and decode it
                memcpu_abl_o <= memcpu_abl_i;       // lower 12 bits are pass-through
                nora_slv_addr_o <= cpu_ab_i;
                nora_slv_rwn_o <= cpu_rw_i;

                // decode CPU address space regions
                if (cpu_abh_i[15:14] == 2'b11)
                begin
                    // CPU address 0xC000 - 0xF000 => 16k ROM banks mapped at the top of SRAM
                    if (rombank_nr[5] == 1'b1)
                    begin
                        // special PBL ROM bank in FPGA
                        nora_slv_req_BOOTROM_o <= 1;
                    end else begin
                        // normal ROM bank in SRAM
                        mem_abh_o <= { 2'b11, rombank_nr[4:0], cpu_abh_i[13:12] };
                        sram_csn_o <= LOW_ACTIVE;
                        mem_rdn_o <= ~cpu_rw_i;
                        mem_wrn_o <= HIGH_INACTIVE;         // never allow writing to the ROM bank!
                    end
                end 
                else if (cpu_abh_i[15:13] == 3'b101)
                begin
                    // CPU address 0xA000 - 0xB000 => 8k RAM banks mapped from the bottom of SRAM
                    mem_abh_o <= { rambank_nr, cpu_abh_i[12] };
                    sram_csn_o <= LOW_ACTIVE;
                    mem_rdn_o <= ~cpu_rw_i;
                    mem_wrn_o <= cpu_rw_i;                    
                end
                else if (cpu_ab_i[15:8] == 8'h9F)
                begin
                    // IO area at 0x9Fxx
                    if (cpu_ab_i[7:4] == 4'h0)
                    begin
                        // 0x9F00 VIA I/O controller #1
                        via_csn_o <= LOW_ACTIVE;
                        mem_rdn_o <= ~cpu_rw_i;
                        mem_wrn_o <= cpu_rw_i;
                        // TBD stretching!!
                    end 
                    else if (cpu_ab_i[7:5] == 4'o1)
                    begin
                        // 0x9F20, 0x9F30 VERA video controller
                        vera_csn_o <= LOW_ACTIVE;
                        mem_rdn_o <= ~cpu_rw_i;
                        mem_wrn_o <= cpu_rw_i;
                    end
                    else if (cpu_ab_i[7:4] == 4'h5)
                    begin
                        // 0x9F50 NORA-SCRB
                        nora_slv_req_SCRB_o <= 1;
                    end
                end
                else if (cpu_ab_i[15:1] == 15'b000000000000000)
                begin
                    // registers 0x0000 RAMBANK and 0x0001 ROMBANK
                    nora_slv_req_BANKREG <= 1;
                end
                else begin
                    // rest: base low memory of CPU mapped to SRAM pages 184-191
                    mem_abh_o <= { 5'h17, cpu_abh_i[15:12] };
                    sram_csn_o <= LOW_ACTIVE;
                    mem_rdn_o <= ~cpu_rw_i;
                    mem_wrn_o <= cpu_rw_i;
                end
            end
            
            if (release_cs || (mst_state == MST_FIN_ACC))
            begin
                // end of CPU or MST access;

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
                            // 0x00 = RAMBANK
                            rambank_nr <= cpu_db_i & rambank_mask_i;
                        end else begin
                            // 0x01 = ROMBANK
                            rombank_nr <= cpu_db_i[5:0];
                        end
                    end
                end

                    // disable memorybus rd/wr flags
                mem_rdn_o <= HIGH_INACTIVE;
                mem_wrn_o <= HIGH_INACTIVE;
                    // disable all CS
                sram_csn_o <= HIGH_INACTIVE;
                via_csn_o <= HIGH_INACTIVE;
                vera_csn_o <= HIGH_INACTIVE;
                vera1_csn_o <= HIGH_INACTIVE;
                vera2_csn_o <= HIGH_INACTIVE;
                nora_slv_req_BOOTROM_o <= 0;
                nora_slv_req_BANKREG <= 0;
                nora_slv_req_SCRB_o <= 0;
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

                    if (nora_mst_req_SRAM_i)
                    begin
                        sram_csn_o <= LOW_ACTIVE;
                    end

                    if (nora_mst_req_OTHER_VIA_i)
                    begin
                        via_csn_o <= LOW_ACTIVE;
                    end

                    if (nora_mst_req_OTHER_VERA_i)
                    begin
                        vera_csn_o <= LOW_ACTIVE;
                    end

                    if (nora_mst_req_OTHER_BOOTROM_i)
                    begin
                        nora_slv_req_BOOTROM_o <= 1;
                    end

                    if (nora_mst_req_OTHER_BANKREG_i)
                    begin
                        nora_slv_req_BANKREG <= 1;
                    end

                    if (nora_mst_req_OTHER_SCRB_i)
                    begin
                        nora_slv_req_SCRB_o <= 1;
                    end

                    if (nora_mst_req_SRAM_i || nora_mst_req_OTHER_VIA_i || nora_mst_req_OTHER_VERA_i)
                    begin
                        mem_rdn_o <= ~nora_mst_rwn_i;
                        mem_wrn_o <= nora_mst_rwn_i;
                    end

                    mst_state <= MST_EXT_ACC;
                end

                MST_EXT_ACC:
                begin
                    mst_state <= MST_FIN_ACC;
                end

                MST_FIN_ACC:
                begin
                    // Finalize master access.
                    // This is performed in addition to release_cs block above;
                    nora_mst_datard_o <= cpu_db_o;          // last cycle: read data is valid now!
                    nora_mst_ack_o <= 1;                // end of master access
                    mst_state <= MST_IDLE;
                    nora_mst_driving_memdb <= 0;        // stop driving the memory bus
                    // disable all CS
                    // sram_csn_o <= HIGH_INACTIVE;
                    // via_csn_o <= HIGH_INACTIVE;
                    // vera_csn_o <= HIGH_INACTIVE;
                    // nora_slv_req_BOOTROM_o <= 0;
                    // nora_slv_req_BANKREG <= 0;
                    // nora_slv_req_SCRB_o <= 0;
                    // disable memorybus rd/wr flags
                    // mem_rdn_o <= HIGH_INACTIVE;
                    // mem_wrn_o <= HIGH_INACTIVE;
                    // enable CPU bus
                    cpu_be_o <= HIGH_ACTIVE;
                end


            endcase
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
                cpu_db_o <= { 3'b000, rombank_nr };
            end
        end
        else if (nora_slv_req_BOOTROM_o || nora_slv_req_SCRB_o)
        begin
            // internal slave reading
            cpu_db_o <= nora_slv_data_i;
        end
    end

endmodule
