/* Copyright (c) 2023-2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/*
 * System Register Control Block mapped at CPU 0x9F50 - 0x9F6F
 */
module sysregs (
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    input           cresn_i,                // CPU Reset, active low
    // NORA SLAVE Interface
    input [4:0]     slv_addr_i,
    input [7:0]     slv_datawr_i,     // write data = available just at the end of cycle!!
    input           slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    output reg [7:0]    slv_datard_o,       // read data
    input           slv_req_i,              // main request (chip select)
    input           slv_req_bregs_i,        // request to the block registers at $00 and $01
    input           slv_rwn_i,           // read=1, write=0
    //
    // ram/rom Block memory-mapping
    // output reg [7:0]   rambank_mask_o,
    output reg [7:0]  mm_block_ab_o,        // which 8kB SRAM block is mapped to address 0xA000-0xBFFF
    output reg [7:0]  mm_block_cd_o,        // which 8kB SRAM block is mapped to address 0xC000-0xDFFF
    output            bootrom_in_block_ef_o,        // Is PBL Bootrom mapped to the block 0xE000-0xFFFF ?
    output reg [7:0]  mm_block_ef_o,        // which 8kB SRAM block is mapped to address 0xE000-0xFFFF, for normal access, in case bootrom_in_block_ef_o=0
    output reg [7:0]  mm_vp_block_ef_o,        // which 8kB SRAM block is mapped to address 0xE000-0xFFFF, for VP (vector pull) access, in case bootrom_in_block_ef_o=0
    output            mirror_bregs_zp_o,            // Regs $9F50-$9F51 are mirrored to $00-$01
    output            auto_unmap_bootrom_o,            // Auto-unmap PBL ROM after RTI instruction
    output [1:0]      rdonly_cdef_o,                // Read-only protection for: [1]=$E000..$FFFF, [0]=$C000..$DFFF.
    input             map_bootrom_i,            // Map PBL ROM to $E000-$FFFF (for ISAFIX handler)
    input             unmap_bootrom_i,            // Unmap PBL ROM from $E000-$FFFF (for ISAFIX handler)
    // SYSCTRL
    output reg      cpu_stop_req_o,
    output reg      cpu_reset_req_o,
    output reg      abrt02_en_o,
    // SPI Master interface for accessing the flash memory
    output [7:0]    spireg_d_o,            // read data output from the core (from the CONTROL or DATA REG)
    input  [7:0]    spireg_d_i,            // write data input to the core (to the CONTROL or DATA REG)
    output          spireg_wr_o,           // write signal
    output          spireg_rd_o,           // read signal
    // output          spireg_ad_i,            // target register select: 0=CONTROL REG, 1=DATA REG.
    output reg      spireg_cs_ctrl_o,
    output reg      spireg_cs_stat_o,
    output reg      spireg_cs_data_o,
    // USB UART
    input [7:0]     usbuart_d_i,            // read data output from the core (from the CONTROL or DATA REG)
    output [7:0]    usbuart_d_o,            // write data input to the core (to the CONTROL or DATA REG)
    output          usbuart_wr_o,           // write signal
    output          usbuart_rd_o,           // read signal
    output reg      usbuart_cs_ctrl_o,           // target register select: CTRL REG
    output reg      usbuart_cs_stat_o,            // target register select: STAT REG
    output reg      usbuart_cs_data_o,            // target register select: DATA REG (FIFO)
    // PS2 KBD and MOUSE
    input [7:0]     ps2_d_i,            // read data output from the core (from the CONTROL or DATA REG)
    output [7:0]    ps2_d_o,            // write data input to the core (to the CONTROL or DATA REG)
    output          ps2_wr_o,           // write signal
    output          ps2_rd_o,           // read signal
    output reg      ps2_cs_ctrl_o,           // target register select: CTRL REG
    output reg      ps2_cs_stat_o,            // target register select: STAT REG
    output reg      ps2_cs_kbuf_o,            // target register select: KBD BUF DATA (FIFO)
    output reg      ps2_cs_krstat_o,            // target register select: KBD RSTAT REG
    output reg      ps2_cs_mbuf_o            // target register select: MOUSE BUF DATA REG (FIFO)
);
    // IMPLEMENTATION

    // chip-select signals:
    reg     ramblock_ab_cs;             // $9F50
    reg     ram_romblock_cf_cs;             // $9F51
    reg     ramblock_mask_cs;           // $9F52
    reg     rmbctrl_cs;                 // $9F53
    reg     sysctrl_cs;                 // $9F54

    // The register slice indicates if the sysctrl register is unlocked for a write.
    // The sysctrl reg is unlocked by first writing the value 0x80.
    reg     sysctrl_unlocked_r;

    // internal registers for the block mapping
    reg [7:0] ramblock_ab_r;            // $9F50, mirrored to $00
    reg [7:0] ram_romblock_cf_r;            // $9F51, mirrored to $01; alias ramblock_cd_r
    reg [7:0] ramblock_mask_r;           // $9F52
    reg [7:0] rmbctrl_r;                // $9F53


    // calculate the slave data read output
    // always @(slv_addr_i, rambank_mask_o, spireg_d_i, slv_req_i, usbuart_d_i) 
    always @(*) 
    begin
        slv_datard_o = 8'h00;
        ramblock_ab_cs = 0;
        ram_romblock_cf_cs = 0;
        ramblock_mask_cs = 0;
        rmbctrl_cs = 0;
        sysctrl_cs = 0;
        usbuart_cs_ctrl_o = 0;
        usbuart_cs_stat_o = 0;
        usbuart_cs_data_o = 0;
        ps2_cs_ctrl_o = 0;           // target register select: CTRL REG
        ps2_cs_stat_o = 0;            // target register select: STAT REG
        ps2_cs_kbuf_o = 0;            // target register select: KBD BUF DATA (FIFO)
        ps2_cs_krstat_o = 0;            // target register select: KBD RSTAT REG
        ps2_cs_mbuf_o = 0;            // target register select: MOUSE BUF DATA REG (FIFO)
        spireg_cs_ctrl_o = 0;
        spireg_cs_stat_o = 0;
        spireg_cs_data_o = 0;

        if (slv_req_bregs_i)
        begin
            // block registers $00 and $01 in the zero page
            if (slv_addr_i[0] == 0)
            begin
                slv_datard_o = ramblock_ab_r;
                ramblock_ab_cs = 1;
            end
            if (slv_addr_i[0] == 1)
            begin
                slv_datard_o = ram_romblock_cf_r;
                ram_romblock_cf_cs = 1;
            end
        end else begin
            // normal registers in the $9F50-$9F6F range
            case (slv_addr_i ^ 5'b10000)
                5'h00: begin            // 0x9F50       RamBLOCK_AB
                    slv_datard_o = ramblock_ab_r;
                    ramblock_ab_cs = slv_req_i;
                end
                5'h01: begin            // 0x9F51       RamBLOCK_CD / ROMBLOCK
                    slv_datard_o = ram_romblock_cf_r;
                    ram_romblock_cf_cs = slv_req_i;
                end
                5'h02: begin            // 0x9F52       RamBMASK
                    slv_datard_o = ramblock_mask_r;       
                    ramblock_mask_cs = slv_req_i;
                end
                5'h03: begin             // 0x9F53      RMBCTRL
                    slv_datard_o = rmbctrl_r;
                    rmbctrl_cs = slv_req_i;
                end
                5'h04: begin            // 0x9F54   SYSCTRL
                    slv_datard_o = { 1'b0, abrt02_en_o, 6'b00_0000 };
                    sysctrl_cs = slv_req_i;
                end
                5'h05: begin        // $9F55           USB_UART_CTRL
                    slv_datard_o = usbuart_d_i;
                    usbuart_cs_ctrl_o = slv_req_i;
                end
                5'h06: begin        // $9F56           USB_UART_STAT                   USB(FTDI)-UART Status
                    slv_datard_o = usbuart_d_i;
                    usbuart_cs_stat_o = slv_req_i;
                end
                5'h07: begin        // $9F57           USB_UART_DATA       [7:0]       Reading dequeues data from the RX FIFO. Writing enqueues to the TX FIFO.
                    slv_datard_o = usbuart_d_i;
                    usbuart_cs_data_o = slv_req_i;
                end
                // 08, 09, 0A => UEXT_UART
                // 0B, 0C, 0D => I2C MASTER
                5'h0E: begin        // $9F5E           PS2_CTRL                        PS2 Control register
                    slv_datard_o = ps2_d_i;
                    ps2_cs_ctrl_o = slv_req_i;
                end
                5'h0F: begin        // $9F5F           PS2_STAT                        PS2 Status Register
                    slv_datard_o = ps2_d_i;
                    ps2_cs_stat_o = slv_req_i;
                end
                5'h10: begin        // $9F60           PS2K_BUF            [7:0]       Keyboard buffer (FIFO output).
                    slv_datard_o = ps2_d_i;
                    ps2_cs_kbuf_o = slv_req_i;
                end
                5'h11: begin        // $9F61           PS2K_RSTAT          [7:0]       Reply status from keyboard (in response from a command).
                    slv_datard_o = ps2_d_i;
                    ps2_cs_krstat_o = slv_req_i;
                end
                5'h12: begin        // $9F62           PS2M_BUF            [7:0]       Mouse buffer (FIFO output).
                    slv_datard_o = ps2_d_i;
                    ps2_cs_mbuf_o = slv_req_i;
                end
                5'h13: begin        // $9F63        N_SPI_CTRL
                    slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                    spireg_cs_ctrl_o = slv_req_i;
                end
                5'h14: begin        // $9F64        N_SPI_STAT
                    slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                    spireg_cs_stat_o = slv_req_i;
                end
                5'h15: begin        // $9F65        N_SPI_DATA
                    slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                    // spireg_cs = slv_req_i;
                    spireg_cs_data_o = slv_req_i;
                end
            endcase
        end
    end

    assign spireg_d_o = slv_datawr_i;
    wire spireg_cs = (spireg_cs_ctrl_o | spireg_cs_data_o | spireg_cs_stat_o);
    assign spireg_wr_o = spireg_cs && !slv_rwn_i && slv_datawr_valid;
    assign spireg_rd_o = spireg_cs && slv_rwn_i && slv_datawr_valid;
    // assign spireg_ad_i = slv_addr_i[0];

    assign usbuart_d_o = slv_datawr_i;
    wire usbuart_cs = (usbuart_cs_ctrl_o | usbuart_cs_stat_o | usbuart_cs_data_o);
    assign usbuart_wr_o = usbuart_cs && !slv_rwn_i && slv_datawr_valid;
    assign usbuart_rd_o = usbuart_cs && slv_rwn_i && slv_datawr_valid;

    assign ps2_d_o = slv_datawr_i;
    wire ps2_cs = (ps2_cs_ctrl_o | ps2_cs_stat_o | ps2_cs_kbuf_o | ps2_cs_krstat_o | ps2_cs_mbuf_o);
    assign ps2_wr_o = ps2_cs && !slv_rwn_i && slv_datawr_valid;
    assign ps2_rd_o = ps2_cs && slv_rwn_i && slv_datawr_valid;


    reg   fpga_boot;

`ifndef SIMULATION
    // fpga warm boot trigger
    SB_WARMBOOT fpgares (
        .BOOT (fpga_boot),
	    .S1 (1'b0),
	    .S0 (1'b0)
    );
`endif

    // programmer-visible registers
    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // in reset
            cpu_stop_req_o <= 0;
            cpu_reset_req_o <= 0;
            abrt02_en_o <= 0;
            sysctrl_unlocked_r <= 0;
            fpga_boot <= 0;
            ramblock_ab_r <= 0;
            ram_romblock_cf_r <= 0;
            ramblock_mask_r <= 8'hFF;       // allow whole memory access through RAM-Blocks
            rmbctrl_r <= 8'h80;          // map bootrom to $E000-$FFFF so that PBL starts
        end else begin
            cpu_stop_req_o <= 0;
            cpu_reset_req_o <= 0;
            // fpga_boot <= 0;

            // handle write to the RAMBLOCK_AB register
            if (ramblock_ab_cs && !slv_rwn_i && slv_datawr_valid)
            begin
                ramblock_ab_r <= slv_datawr_i;
            end

            // handle write to the RAMBLOCK_CD register
            if (ram_romblock_cf_cs && !slv_rwn_i && slv_datawr_valid)
            begin
                ram_romblock_cf_r <= slv_datawr_i;
            end

            // handle write to the RAMBANK_MASK register
            if (ramblock_mask_cs && !slv_rwn_i && slv_datawr_valid)
            begin
                ramblock_mask_r <= slv_datawr_i;
            end

            // handle write to the RMBCTRL register
            if (rmbctrl_cs && !slv_rwn_i && slv_datawr_valid)
            begin
                rmbctrl_r <= slv_datawr_i;
            end

            // Handle map/unmap of the PBL ROM via special signals map_bootrom_i and unmap_bootrom_i.
            // This directly changes the bit [7] of RMBCTRL register.
            if (map_bootrom_i)
            begin
                // set bit 7 to 1 to force the PBL ROM
                rmbctrl_r <= { 1'b1, rmbctrl_r[6:0] };
            end

            if (unmap_bootrom_i)
            begin
                // clear bits 7 & 6 to 0 to clear us out of the PBL ROM
                rmbctrl_r <= { 2'b00, rmbctrl_r[5:0] };
            end

            // handle write to the SYSCTRL register
            if (sysctrl_cs && !slv_rwn_i && slv_datawr_valid)
            begin
                // writing 0x80 will unlock the register
                if (slv_datawr_i == 8'h80)
                begin
                    sysctrl_unlocked_r <= 1;
                end
                // if the register is unlocked...
                if (sysctrl_unlocked_r && !slv_datawr_i[7])
                begin
                    // write ABRT02
                    abrt02_en_o <= slv_datawr_i[6];

                    // [2] NORARESET ?
                    if (slv_datawr_i[2])
                    begin
                        fpga_boot <= 1;
                    end

                    // [1] bit CPUSTOP
                    if (slv_datawr_i[1])
                    begin
                        cpu_stop_req_o <= 1;
                    end

                    // [0] bit CPURESET
                    if (slv_datawr_i[0])
                    begin
                        cpu_reset_req_o <= 1;
                    end
                    
                    // lock the register again
                    sysctrl_unlocked_r <= 0;
                end
            end

            if (!cresn_i)
            begin
                // CPU reset is active!
                // Disable ABRT02 handler
                abrt02_en_o <= 0;
                // lock SYSCTRL
                sysctrl_unlocked_r <= 0;
            end
        end
    end


    // calculate the block mapping outputs that can be directly used by the bus_controller module
    always @(posedge clk)
    begin
        // output reg [7:0]  mm_block_ab_o,        // which 8kB SRAM block is mapped to address 0xA000-0xBFFF
        mm_block_ab_o <= (ramblock_ab_r & ramblock_mask_r) ^ 8'h80;

        if (rmbctrl_r[4])               // [4] bit ENABLE_RO_CF:
        begin
            // ROM-Blocks are enabled.
            // output reg [7:0]  mm_block_cd_o,        // which 8kB SRAM block is mapped to address 0xC000-0xDFFF
                // normal access through the active rompage, starting at SRAM Page 64
            mm_block_cd_o <= { 2'b01, ram_romblock_cf_r[4:0], 1'b0 };
            
            // output reg [7:0]  mm_block_ef_o,        // which 8kB SRAM block is mapped to address 0xE000-0xFFFF, for normal access, in case bootrom_in_block_ef_o=0
            mm_block_ef_o <= { 2'b01, ram_romblock_cf_r[4:0], 1'b1 };
            
            // output reg [7:0]  mm_vp_block_ef_o,        // which 8kB SRAM block is mapped to address 0xE000-0xFFFF, for VP (vector pull) access, in case bootrom_in_block_ef_o=0
                // In case of Vector Pull cycle (cpu_vpu_i is active low) -> must access the rombank 0x00 always!
            mm_vp_block_ef_o <= { 2'b01, 5'b00000, 1'b1 };

        end else begin 
            // ROM-Blocks are disabled

            if (rmbctrl_r[3])           // [3] bit ENABLE_RAM_CF:
            begin
                // Second RAM-Block at $C000-$DFFF is ENABLED
                mm_block_cd_o <= (ram_romblock_cf_r & ramblock_mask_r) ^ 8'h80;
            end else begin
                // Second RAM-Block at $C000-$DFFF is DISABLED
                mm_block_cd_o <= 8'h06;       // SRAM 8k-Block 6
            end

            // direct mapping to SRAM
            mm_block_ef_o <= 8'h07;       // SRAM 8k-Block 7
            mm_vp_block_ef_o <= 8'h07;       // SRAM 8k-Block 7 also for Vector Pull
        end
    end

    // output         bootrom_in_block_ef_o,        // Is PBL Bootrom mapped to the block 0xE000-0xFFFF ?
    assign bootrom_in_block_ef_o = rmbctrl_r[7];

    // output         auto_unmap_bootrom_o,            // Auto-unmap PBL ROM after RTI instruction
    assign auto_unmap_bootrom_o = rmbctrl_r[6];

    // output        mirror_bregs_zp_o,            // Regs $9F50-$9F51 are mirrored to $00-$01
    assign mirror_bregs_zp_o = rmbctrl_r[5];

    // output [1:0]      rdonly_cdef_o,                // Read-only protection for: [1]=$E000..$FFFF, [0]=$C000..$DFFF.
    assign rdonly_cdef_o = rmbctrl_r[2:1];

endmodule
