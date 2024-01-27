/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * Internal RAM / BOOTROM
 * Single-ported RAM with NORA Slave interface.
 * We expect synthesis in RAM4K, i.e. with 8-bit data width one RAM4K holds 512 rows (512 Bytes)
 */
module bootrom #(
    parameter       BITDEPTH = 9
) (
    // Global signals
    input           clk,        // 48MHz
    input           resetn,     // sync reset
    // NORA slave interface - internal devices
    input [BITDEPTH-1:0]     slv_addr_i,
    input [7:0]     slv_datawr_i,     // write data = available just at the end of cycle!!
    input           slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    output reg [7:0]    slv_datard_o,       // read data
    input           slv_req_i,          // request (chip select)
    input           slv_rwn_i           // read=1, write=0
);
    // IMPLEMENTATION

    reg [7:0]   rom [0:2**BITDEPTH-1];


    // read from ROM
    always @(posedge clk) 
    begin
        slv_datard_o <= rom[slv_addr_i[BITDEPTH-1:0]];
    end

    // write to ROM
    always @(posedge clk)
    begin
        if (slv_req_i && !slv_rwn_i && slv_datawr_valid)
        begin
            rom[slv_addr_i[BITDEPTH-1:0]] <= slv_datawr_i;
        end
    end



    initial 
    begin
        // read file in hex format
        $readmemh("../rom/pbl.mem", rom);
        // $readmemh("../rom-blinker/pbl.mem", rom);
    end
endmodule
