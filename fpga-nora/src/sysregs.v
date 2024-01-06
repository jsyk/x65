/* Copyright (c) 2023-2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/*
 * System Register Control Block mapped at CPU 0x9F50 - 0x9F6F
 */
module sysregs (
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    // NORA SLAVE Interface
    input [4:0]     slv_addr_i,
    input [7:0]     slv_datawr_i,     // write data = available just at the end of cycle!!
    input           slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    output reg [7:0]    slv_datard_o,       // read data
    input           slv_req_i,          // request (chip select)
    input           slv_rwn_i,           // read=1, write=0
    //
    // RAMBANK_MASK
    output reg [7:0]   rambank_mask_o,
    // SPI Master interface for accessing the flash memory
    output [7:0]    spireg_d_o,            // read data output from the core (from the CONTROL or DATA REG)
    input  [7:0]    spireg_d_i,            // write data input to the core (to the CONTROL or DATA REG)
    output          spireg_wr_i,           // write signal
    output          spireg_rd_i,           // read signal
    output          spireg_ad_i,            // target register select: 0=CONTROL REG, 1=DATA REG.
    // USB UART
    input [7:0]     usbuart_d_i,            // read data output from the core (from the CONTROL or DATA REG)
    output [7:0]    usbuart_d_o,            // write data input to the core (to the CONTROL or DATA REG)
    output          usbuart_wr_o,           // write signal
    output          usbuart_rd_o,           // read signal
    output reg      usbuart_cs_ctrl_o,           // target register select: CTRL REG
    output reg      usbuart_cs_stat_o,            // target register select: STAT REG
    output reg      usbuart_cs_data_o            // target register select: DATA REG (FIFO)

);
    // IMPLEMENTATION

    reg spireg_cs;
    reg rambank_mask_cs;


    // calculate the slave data read output
    always @(slv_addr_i, rambank_mask_o, spireg_d_i, slv_req_i, usbuart_d_i) 
    begin
        slv_datard_o = 8'h00;
        spireg_cs = 0;
        rambank_mask_cs = 0;
        usbuart_cs_ctrl_o = 0;
        usbuart_cs_stat_o = 0;
        usbuart_cs_data_o = 0;

        case (slv_addr_i ^ 5'b10000)
            5'h00: begin            // 0x9F50
                slv_datard_o = rambank_mask_o;       // RAMBANK_MASK
                rambank_mask_cs = slv_req_i;
            end
            5'h02, 5'h03: begin     // 0x9F52, 9F53
                slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                spireg_cs = slv_req_i;
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
        endcase
    end

    assign spireg_d_o = slv_datawr_i;
    assign spireg_wr_i = spireg_cs && !slv_rwn_i && slv_datawr_valid;
    assign spireg_rd_i = spireg_cs && slv_rwn_i && slv_datawr_valid;
    assign spireg_ad_i = slv_addr_i[0];

    assign usbuart_d_o = slv_datawr_i;
    assign usbuart_wr_o = (usbuart_cs_ctrl_o | usbuart_cs_stat_o | usbuart_cs_data_o) && !slv_rwn_i && slv_datawr_valid;
    assign usbuart_rd_o = (usbuart_cs_ctrl_o | usbuart_cs_stat_o | usbuart_cs_data_o) && slv_rwn_i && slv_datawr_valid;

    // registers
    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // in reset
            rambank_mask_o <= 8'h7F;       // X16 compatibility: allow only 128 RAM banks after reset
        end else begin
            // handle write to the RAMBANK_MASK register
            if (rambank_mask_cs && !slv_rwn_i && slv_datawr_valid)
            begin
                rambank_mask_o <= slv_datawr_i;
            end
        end
    end
endmodule
