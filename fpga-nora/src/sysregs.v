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

    // reg spireg_cs;
    reg rambank_mask_cs;


    // calculate the slave data read output
    // always @(slv_addr_i, rambank_mask_o, spireg_d_i, slv_req_i, usbuart_d_i) 
    always @(*) 
    begin
        slv_datard_o = 8'h00;
        // spireg_cs = 0;
        rambank_mask_cs = 0;
        usbuart_cs_ctrl_o = 0;
        usbuart_cs_stat_o = 0;
        usbuart_cs_data_o = 0;
        spireg_cs_ctrl_o = 0;
        spireg_cs_stat_o = 0;
        spireg_cs_data_o = 0;
        ps2_cs_ctrl_o = 0;           // target register select: CTRL REG
        ps2_cs_stat_o = 0;            // target register select: STAT REG
        ps2_cs_kbuf_o = 0;            // target register select: KBD BUF DATA (FIFO)
        ps2_cs_krstat_o = 0;            // target register select: KBD RSTAT REG
        ps2_cs_mbuf_o = 0;            // target register select: MOUSE BUF DATA REG (FIFO)

        case (slv_addr_i ^ 5'b10000)
            5'h00: begin            // 0x9F50
                slv_datard_o = rambank_mask_o;       // RAMBANK_MASK
                rambank_mask_cs = slv_req_i;
            end
            5'h02: begin        // $9F52        N_SPI_CTRL
                slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                spireg_cs_ctrl_o = slv_req_i;
            end
            5'h03: begin        // $9F53        N_SPI_STAT
                slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                spireg_cs_stat_o = slv_req_i;
            end
            5'h04: begin        // $9F54        N_SPI_DATA
                slv_datard_o = spireg_d_i;           // SPI MASTER/ READ CONTROL or DATA REG
                // spireg_cs = slv_req_i;
                spireg_cs_data_o = slv_req_i;
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

        endcase
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
