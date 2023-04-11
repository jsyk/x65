/**
 * ICD = In-Circuit Debugger, normally driven from SPI-Slave connected to the USB/FTDI
 * port on the OpenX65 computer.
 *
 * Structure of the 1st header byte :
 *   [ <7:4>     <3:0> ]
 *              0x0         GETSTATUS
 *
 *              0x1         BUS/MEM ACCESS
 *      `----------------------->   <4>     0 => SRAM, 1 => OTHER
 *                                  <5>     0 => WRITE, 1 => READ
 *                                  <6>     0 => ADR-KEEP, 1 => ADR-INC
 *                                  <7>     reserved
 *                          2nd, 3rd, 4th byte = 24b Memory address, little-endian (note: SPI is MSBit-first).
 *                                                  SRAM => [23:21]=0, [20:0]=SRAM_Addr
 *                                                  OTHER => [23:21]=0,
 *                                                           [20]=BOOTROM_CS
 *                                                           [19]=BANKREG_CS
 *                                                           [18]=SCRB_CS
 *                                                           [17]=VERA_CS
 *                                                           [16]=VIA_CS
 *                          5th byte = READ=>dummy_byte, WRITE=>1st-wr_byte.
 *                          6th, 7th... bytes = READ/WRITE data bytes.
 *
 *              0x2         CPU CTRL
 */
module icd_controller (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // ICD-SPI_Slave Received data
    input [7:0]     rx_byte_i,     // received byte data
    input           rx_hdr_en_i,    // flag: received first byte
    input           rx_db_en_i,     // flag: received next byte
    // ICD-SPI_Slave Send data
    output reg [7:0]  tx_byte_o,      // transmit byte
    output reg        tx_en_o,         // flag: catch the transmit byte

    // NORA master interface - internal debug controller
    output reg   [23:0]  nora_mst_addr_o,
    output reg   [7:0]   nora_mst_data_o,
    input [7:0]         nora_mst_datard_i,
    input           nora_mst_ack_i,                 // end of access, also nora_mst_datard_o is valid now.
    output reg      nora_mst_req_SRAM_o,
    output reg      nora_mst_req_OTHER_o,
    // output reg      nora_mst_req_BOOTROM_o,
    // output reg      nora_mst_req_BANKREG_o,
    // output reg      nora_mst_req_SCRB_o,
    // output reg      nora_mst_req_VIA_o,
    // output reg      nora_mst_req_VERA_o,
    output reg      nora_mst_rwn_o
);
// IMPLEMENTATION

    parameter CMD_GETSTATUS = 4'h0;
    parameter CMD_BUSMEM_ACC = 4'h1;
    parameter CMD_CPUCTRL = 4'h2;

    parameter nSRAM_OTHER_BIT = 4;
    parameter nWRITE_READ_BIT = 5;
    parameter ADR_INC_BIT = 6;

    reg [7:0]   icd_cmd;        // first byte
    reg [3:0]   counter;        // data bytes counter, saturates.


    always @(posedge clk6x)
    begin
        tx_en_o <= 0;

        if (!resetn)
        begin
            icd_cmd <= 0;
            counter <= 0;

            // nora_mst_req_BOOTROM_o <= 0;
            // nora_mst_req_BANKREG_o <= 0;
            // nora_mst_req_SCRB_o <= 0;
            nora_mst_req_SRAM_o <= 0;
            nora_mst_req_OTHER_o <= 0;
            // nora_mst_req_VIA_o <= 0;
            // nora_mst_req_VERA_o <= 0;
            nora_mst_rwn_o <= 1;
        end else begin
            if (rx_hdr_en_i)
            begin
                // header/command byte received
                icd_cmd <= rx_byte_i;
                counter <= 0;
            end

            // if (rx_db_en_i)
            // begin
            //     tx_byte_o <= icd_cmd + rx_byte_i;
            //     tx_en_o <= 1;
            // end

            if ((icd_cmd[3:0] == CMD_BUSMEM_ACC) && rx_db_en_i)
            begin
                // Handle BUS/MEM ACCESS
                //
                if (counter < 3)
                begin
                    // store the bus address, LSB first
                    nora_mst_addr_o <= { rx_byte_i, nora_mst_addr_o[23:8] };
                    counter <= counter + 1;

                    tx_byte_o <= rx_byte_i;
                    tx_en_o <= 1;

                    if ((icd_cmd[nWRITE_READ_BIT] == 1) && (counter == 2))
                    begin
                        // start SRAM read (we have all we need); 
                        // (for a write, we need at least 1 more byte - wr-data)
                        nora_mst_req_SRAM_o <= 1;
                        nora_mst_rwn_o <= icd_cmd[nWRITE_READ_BIT];
                    end
                end else begin
                    // counter == 3; multiple bytes
                    // start SRAM write, or continue SRAM read
                    nora_mst_req_SRAM_o <= 1;
                    nora_mst_rwn_o <= icd_cmd[nWRITE_READ_BIT];
                    nora_mst_data_o <= rx_byte_i;       // ignored on read
                end
            end

            if (nora_mst_ack_i)
            begin
                // send the byte from a bus to SPI-slave
                tx_byte_o <= nora_mst_datard_i;
                tx_en_o <= 1;
                // deselect bus devices
                nora_mst_req_SRAM_o <= 0;
                // increment bus address?
                if (icd_cmd[ADR_INC_BIT])
                begin
                    nora_mst_addr_o <= nora_mst_addr_o + 1;
                end
            end
        end
    end


endmodule
