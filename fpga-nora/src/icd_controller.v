/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * ICD = In-Circuit Debugger, normally driven from SPI-Slave connected to the USB/FTDI
 * port on the OpenX65 computer.
 *
 * Structure of the 1st header byte :
 *   [ 7:4  ,   3:0 ]
 *    opts  , command
 *              0x0         GETSTATUS
 *
 *      |       0x1         BUS/MEM ACCESS
 *      `----------------------->   [4]     0 => SRAM, 1 => OTHER
 *                                  [5]     0 => WRITE, 1 => READ
 *                                  [6]     0 => ADR-KEEP, 1 => ADR-INC
 *                                  [7]     reserved
 *                          2nd, 3rd, 4th byte = 24b Memory address, little-endian (note: SPI is MSBit-first).
 *                                                  SRAM => [23:21]=0, [20:0]=SRAM_Addr
 *                                                  OTHER => [23:21]=0,
 *                                                           [20]=BOOTROM_CS
 *                                                           [19]=BANKREG_CS
 *                                                           [18]=IOREGS (256B area, decoded as in CPU)
 *                          5th byte = READ=>dummy_byte, WRITE=>1st-wr_byte.
 *                          6th, 7th... bytes = READ/WRITE data bytes.
 *
 *      |       0x2         CPU CTRL
 *      `----------------------->   [4]     0 => Stop CPU, 1 => RUN CPU (indefinitely)
 *                                  [5]     0 => no-action, 1 => Single-Cycle-Step CPU (it must be stopped prior)
 *                          2nd byte = forcing of CPU control signals
 *                                  [0]     0 => reset not active, 1 => CPU reset active!
 *
 *              0x3         READ CPU TRACE REG
 *                          TX:2nd byte = dummy
 *                          TX:3rd byte = status of trace buffer:
 *                                          VALID => [0]
 *                                          OVERFLOWED => [1]
 *                                          reserved = [7:2]
 *                          TX:4th, 5th... byte = trace buffer contents, starting from LSB byte.
 *
 */
module icd_controller #(
    parameter CPUTRACE_WIDTH = 40
) (
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
    output reg      nora_mst_rwn_o,

    // CPU control/status
    output reg      run_cpu,                // allow the CPU to run
    input           stopped_cpu,            // indicates if the CPU is stopped
    output reg      cpu_force_resn_o,       // 0 will force CPU reset

    // Trace input
    input [CPUTRACE_WIDTH-1:0]    cpubus_trace_i,
    input           trace_catch_i
);
// IMPLEMENTATION

    // protocol constants: commands
    localparam CMD_GETSTATUS = 4'h0;
    localparam CMD_BUSMEM_ACC = 4'h1;
    localparam CMD_CPUCTRL = 4'h2;
    localparam CMD_READTRACE = 4'h3;
    // arguments
    localparam nSRAM_OTHER_BIT = 4;
    localparam nWRITE_READ_BIT = 5;
    localparam ADR_INC_BIT = 6;

    // command byte from the host
    reg [7:0]   icd_cmd;        // first byte
    reg [3:0]   counter;        // data bytes counter, saturates.

    // trace of the CPU/BUS
    reg [CPUTRACE_WIDTH-1:0]    cpubus_trace_reg;
    reg                         tracereg_valid;
    reg                         tracereg_ovf;           // overflowed

    // indicates that the CPU should be stopped just after one cycle
    reg     single_step_cpu;

    // startup FSM - states
    // TBD: make possible to start in debug mode!
    localparam STARTUP_INIT = 2'b00;
    localparam STARTUP_WAIT_RESB = 2'b01;
    localparam STARTUP_RUN = 2'b10;
    localparam STARTUP_DONE = 2'b11;
    
    // state machine for the FPGA cold start
    reg [1:0]    startup_fsm_r;
    reg [3:0]    startup_cnt_r;

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
// `ifdef SIMULATION
            // run_cpu <= 1;                   // sim starts in run!!
// `else
            run_cpu <= 0;                   // CPU starts in stop!!
// `endif
            cpu_force_resn_o <= 0;          // this will force reset!!
            single_step_cpu <= 0;
            tracereg_valid <= 0;
            tracereg_ovf <= 0;
            startup_fsm_r <= STARTUP_INIT;
            startup_cnt_r <= 15;
        end else begin
            if (rx_hdr_en_i)
            begin
                // header/command byte received
                icd_cmd <= rx_byte_i;
                counter <= 0;

                // cpubus_trace_reg <= 40'h12_34_56_78_9A;

                if (rx_byte_i[3:0] == CMD_READTRACE)
                begin
                    // Handle READ CPU TRACE command
                    //
                    // first data byte -> return trace buffer status: valid, ovf
                    tx_byte_o <= { 6'b000000, tracereg_ovf, tracereg_valid };
                    tx_en_o <= 1;
                    // reset the status bits
                    tracereg_ovf <= 0;
                    tracereg_valid <= 0;
                end
            end

            // if (rx_db_en_i)
            // begin
            //     tx_byte_o <= icd_cmd + rx_byte_i;
            //     tx_en_o <= 1;
            // end

            if ((icd_cmd[3:0] == CMD_BUSMEM_ACC) && rx_db_en_i)
            begin
                // Handle BUS/MEM ACCESS command
                //
                if (counter < 3)
                begin
                    // store the bus address, LSB first
                    nora_mst_addr_o <= { rx_byte_i, nora_mst_addr_o[23:8] };
                    counter <= counter + 4'd1;

                    tx_byte_o <= rx_byte_i;
                    tx_en_o <= 1;

                    if ((icd_cmd[nWRITE_READ_BIT] == 1) && (counter == 2))
                    begin
                        // start SRAM/OTHER read (we have all we need); 
                        // (for a write, we need at least 1 more byte - wr-data)
                        nora_mst_req_SRAM_o <= ~icd_cmd[4];
                        nora_mst_req_OTHER_o <= icd_cmd[4];
                        nora_mst_rwn_o <= icd_cmd[nWRITE_READ_BIT];
                    end
                end else begin
                    // counter == 3; multiple bytes
                    // start SRAM/OTHER write, or continue SRAM/OTHER read
                    nora_mst_req_SRAM_o <= ~icd_cmd[4];
                    nora_mst_req_OTHER_o <= icd_cmd[4];
                    nora_mst_rwn_o <= icd_cmd[nWRITE_READ_BIT];
                    nora_mst_data_o <= rx_byte_i;       // ignored on read
                end
            end

            if ((icd_cmd[3:0] == CMD_CPUCTRL) && rx_db_en_i)
            begin
                // Handle CPU CTRL command
                //
                if (counter == 0)
                begin
                    // decode command bits
                    run_cpu <= icd_cmd[4];          // RUN indefinitely
                    // single-step?
                    if (icd_cmd[5]) 
                    begin
                        run_cpu <= 1;
                        single_step_cpu <= 1;
                    end
                    // first data byte -> set control signals
                    cpu_force_resn_o <= ~rx_byte_i[0];
                    counter <= counter + 1;
                end
            end

            if ((icd_cmd[3:0] == CMD_READTRACE) && rx_db_en_i)
            begin
                // Handle READ CPU TRACE command
                //
                // if (counter == 0)
                // begin
                //     // first data byte -> return trace buffer status: valid, ovf
                //     tx_byte_o <= { 6'b000000, tracereg_ovf, tracereg_valid };
                //     tx_en_o <= 1;
                //     // reset the status bits
                //     tracereg_ovf <= 0;
                //     tracereg_valid <= 0;
                //     // next provide trace bytes
                //     counter <= counter + 1;
                // end else begin
                    // 2nd and further data bytes -> provide trace buffer (LSB 8 bits)
                    tx_byte_o <= cpubus_trace_reg[7:0];
                    tx_en_o <= 1;
                    // shift the trace buffer right by 8 bits - prepare for next access
                    cpubus_trace_reg <= { 8'h00, cpubus_trace_reg[CPUTRACE_WIDTH-1:8] };
                // end
            end

            // finishing a bus/mem access?
            if (nora_mst_ack_i)
            begin
                // send the byte from a bus to SPI-slave
                tx_byte_o <= nora_mst_datard_i;
                tx_en_o <= 1;
                // deselect bus devices
                nora_mst_req_SRAM_o <= 0;
                nora_mst_req_OTHER_o <= 0;
                // increment bus address?
                if (icd_cmd[ADR_INC_BIT])
                begin
                    nora_mst_addr_o <= nora_mst_addr_o + 24'd1;
                end
            end

            // catch the trace into a register?
            if (trace_catch_i)
            begin
                tracereg_ovf <= tracereg_valid;
                tracereg_valid <= 1;
                cpubus_trace_reg <= cpubus_trace_i;
            end

            // finishing a single-step command?
            if (single_step_cpu && !stopped_cpu)
            begin
                run_cpu <= 0;
                single_step_cpu <= 0;
            end

            // handle startup sequence
            case (startup_fsm_r)
                STARTUP_INIT:
                begin
                    // initialize CPU reset/startup sequence:
                    run_cpu <= 0;
                    cpu_force_resn_o <= 0;          // this will force reset!!
                    single_step_cpu <= 0;
                    startup_cnt_r <= 15;
                    startup_fsm_r <= STARTUP_WAIT_RESB;
                end

                STARTUP_WAIT_RESB:
                begin
                    // run the CPU, while keeping reset active for 15 u-cycles
                    // TBD: we should check CPHI2 for at least 2 cycles gone!!
                    run_cpu <= 1;
                    startup_cnt_r <= startup_cnt_r - 1;
                    // done?
                    if (startup_cnt_r == 0)
                    begin
                        startup_fsm_r <= STARTUP_RUN;
                    end
                end

                STARTUP_RUN:
                begin
                    // run the CPU, deactivate the reset
                    run_cpu <= 1;
                    cpu_force_resn_o <= 1;
                    startup_fsm_r <= STARTUP_DONE;
                end

                STARTUP_DONE:
                begin
                    // no action here!
                    startup_fsm_r <= STARTUP_DONE;
                end
            endcase
        end
    end


endmodule
