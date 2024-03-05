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
 *                          TX:2nd byte = dummy
 *                          TX:3rd byte = status of CPU / ICD
 *                                  [0]    TRACE-REG VALID
 *                                  [1]    TRACE-REG OVERFLOWED
 *                                  [2]    TRACE-BUF NON-EMPTY (note: status before a dequeue or clear!)
 *                                  [3]    TRACE-BUF FULL (note: status before a dequeue or clear!)
 *                                  [4]    CPU-RUNNING? If yes (1), then trace register reading is not allowed (inconsistent)!!
 *                                          reserved = [7:5]
 *                          TX:4th byte = trace REGISTER contents: LSB byte (just read, not shifting!!)
 *
 *      |       0x1         BUS/MEM ACCESS
 *      `----------------------->   [4]     0 => SRAM, 1 => OTHER
 *                                  [5]     0 => WRITE, 1 => READ
 *                                  [6]     0 => ADR-KEEP, 1 => ADR-INC
 *                                  [7]     reserved
 *                          RX 2nd, 3rd, 4th byte = 24b Memory address, little-endian (note: SPI is MSBit-first).
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
 *                          RX 2nd byte = forcing or blocking of CPU control signals
 *                                  [0]     0 => reset not active, 1 => CPU reset active!
 *                                  [1]     0 => IRQ not active, 1 => IRQ forced!
 *                                  [2]     0 => NMI not active, 1 => NMI forced!
 *                                  [3]     0 => ABORT not active, 1 => ABORT forced!
 *                                  [4]     0 => IRQ not blocked, 1 => IRQ blocked!
 *                                  [5]     0 => NMI not blocked, 1 => NMI blocked!
 *                                  [6]     0 => ABORT not blocked, 1 => ABORT blocked!
 *                                  [7]     unused
 *
 *      |       0x3         READ CPU TRACE REG
 *      `----------------------->   [4]     1 => Dequeue next trace-word from trace-buffer memory into the trace-reg
 *                                  [5]     1 => Clear the trace buffer memory.
 *                                  [6]     1 => Sample the trace reg from actual CPU state; only allowed if the CPU is stopped,
                                                 and the trace reg should be empty to avoid loosing any previous data.
 *                          TX:2nd byte = dummy
 *                          TX:3rd byte = status of trace buffer:
 *                                  [0]    TRACE-REG VALID
 *                                  [1]    TRACE-REG OVERFLOWED
 *                                  [2]    TRACE-BUF NON-EMPTY (note: status before a dequeue or clear!)
 *                                  [3]    TRACE-BUF FULL (note: status before a dequeue or clear!)
 *                                  [4]    CPU-RUNNING? If yes (1), then trace register reading is not allowed (returns dummy)!!
 *                                          reserved = [7:5]
 *                          TX:4th, 5th... byte = trace REGISTER contents, starting from LSB byte.
 *
 *      |       0x4         GET/SET BREAK CONDITIONS MASK
 *      `----------------------->   [4]     1 => Set bitmask below, 0 => Don't set/just read (RX 2nd/3rd byte is ignored).
 *                          RX 2nd byte = mask of enabled BREAK conditions - 1st byte, TO BE SET:
 *                                  [0]     CPU EF low = Native mode, output active?
 *                                  [1]     CPU EF high = emulation mode, output active?
 *                                  [2]     CPU Vector Pull output active?
 *                                  [3]     CPU ABORT input active?
 *                                  [4]     CPU NMI input active?
 *                                  [5]     CPI IRQ input active?
 *                                  [6]     CPU Reset input active?
 *                                  [7]     reserved, 0
 *                          RX 3rd byte, mask 2nd byte, TO BE SET:
 *                                  [0]     Breakpoint address #1 active?
 *                                  [1]     Breakpoint address #2 active?
 *                                  [2-7]   reserved, 0
 *
 *                          TX:2nd byte = dummy
 *                          TX:3rd byte = mask of enabled BREAK conditions, TO BE READ.
 *                          TX:4th byte = mask 2nd byte, TO BE READ.
 *
 *      |       0x5         GET/SET BREAKPOINT ADDRESS
 *      `----------------------->   [4]     1 => Set bitmask below, 0 => Don't set/just read (RX 2nd/3rd byte is ignored).
 *                                  [5]     0 => HW-Breakpoint #1, 1 => HW-Breakpoint #2
 *                          RX 2nd byte = matching cpu_ab lsd
 *                          RX 3rd byte = matching cpu_ab msd
 *                          RX 4th byte = matching cpu_ab
 *                          RX 5nd byte = mask cpu_ab lsd
 *                          RX 6rd byte = mask cpu_ab msd
 *                          RX 7th byte = mask cpu_ab
 *                          
 *      |       0x6         FORCE CPU DATA BUS
 *      `----------------------->   [4]     1 => force opcode as the 2nd byte, 0 => ignore the second byte / no opcode force.
 *                                  [5]     1 => ignore Writes, 0 => normal writes.
 *                          RX 2nd byte = byte for the CPU DB (opcode or opcode arg)
 *
 */
module icd_controller #(
    parameter CPUTRACE_WIDTH = 48,
    parameter CPUTRACE_DEPTH = 8
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
    input           cpu_stop_i,
    input           cpu_reset_i,            // request reset sequence

    output reg      cpu_force_resn_o,       // 0 will force CPU reset
    output reg      cpu_force_irqn_o,       // 0 will force CPU IRQ
    output reg      cpu_force_nmin_o,       // 0 will force CPU NMI
    output reg      cpu_force_abortn_o,       // 0 will force CPU ABORT (16b only)
    output reg      cpu_block_irq_o,       // 1 will block CPU IRQ
    output reg      cpu_block_nmi_o,       // 1 will block CPU NMI
    output reg      cpu_block_abort_o,       // 1 will block CPU ABORT

    // ICD->CPU forcing of opcode
    output reg      force_cpu_db_o,
    output reg      ignore_cpu_writes_o,
    output reg [7:0] cpu_db_forced_o,
    
    // Trace input
    input [CPUTRACE_WIDTH-1:0]    cpubus_trace_i,
    input           trace_catch_i,
    input           release_cs_i
);
// IMPLEMENTATION

    // protocol constants: commands
    localparam CMD_GETSTATUS = 4'h0;
    localparam CMD_BUSMEM_ACC = 4'h1;
    localparam CMD_CPUCTRL = 4'h2;
    localparam CMD_READTRACEREG = 4'h3;
    localparam CMD_FORCECDB = 4'h6;
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

    // signals for trace buffer
    wire        trb_wenq;                           // insert into trace buffer
    wire [CPUTRACE_WIDTH-1:0]  trb_rport;            // read data from trace buffer
    reg         trb_rdeq;                           // remove from trace buffer
    reg         trb_clear;                          // clear (reset) the trace buffer
    wire        trb_full;                           // flag: trace buffer is full
    wire        trb_empty;                          // flag: trace buffer is empty
    wire [CPUTRACE_DEPTH:0]    trb_count;

    // trace buffer
    tracebuf #(
        .BITWIDTH (CPUTRACE_WIDTH),          // bit-width of one data element
        .BITDEPTH (CPUTRACE_DEPTH)          // buffer keeps 2**BITDEPTH elements
    ) tbuf (
        // Global signals
        .clk        (clk6x),        // 48MHz
        .resetn     (resetn),     // sync reset
        // I/O Write port
        .wport_i    (cpubus_trace_reg),          // Write Port Data
        .wenq_i     (trb_wenq),                 // Enqueue data from the write port now; must not assert when full_o=1
        // I/O read port
        .rport_o    (trb_rport),          // Read port data: valid any time empty_o=0
        .rdeq_i     (trb_rdeq),                 // Dequeue current data from FIFO
        .clear_i    (trb_clear),                // Clear the buffer (reset)
        // Status signals
        .full_o     (trb_full),                 // FIFO is full?
        .empty_o    (trb_empty),                // FIFO is empty?
        .count_o    (trb_count)       // count of elements in the FIFO now; mind the width of the reg!

    );

    always @(posedge clk6x)
    begin
        tx_byte_o <= 8'h00;
        tx_en_o <= 0;

        if (!resetn)
        begin
            icd_cmd <= 0;
            counter <= 0;

            nora_mst_req_SRAM_o <= 0;
            nora_mst_req_OTHER_o <= 0;
            nora_mst_rwn_o <= 1;
            run_cpu <= 0;                   // CPU starts in stop!!
            cpu_force_resn_o <= 0;          // this will force reset!!
            cpu_force_irqn_o <= 1;          // 1=inactive
            cpu_force_nmin_o <= 1;          // 1=inactive
            cpu_force_abortn_o <= 1;        // 1=inactive
            cpu_block_irq_o <= 0;           // 0=inactive
            cpu_block_nmi_o <= 0;           // 0=inactive
            cpu_block_abort_o <= 0;         // 0=inactive
            single_step_cpu <= 0;
            tracereg_valid <= 0;
            tracereg_ovf <= 0;
            startup_fsm_r <= STARTUP_INIT;
            startup_cnt_r <= 15;
            trb_rdeq <= 0;
            trb_clear <= 0;
            force_cpu_db_o <= 0;
            ignore_cpu_writes_o <= 0;
            cpu_db_forced_o <= 8'h00;
        end else begin
            // always reset signals
            trb_rdeq <= 0;
            trb_clear <= 0;

            if (rx_hdr_en_i)
            begin
                // header/command byte received
                icd_cmd <= rx_byte_i;
                counter <= 0;

                // default: clear TX byte!
                tx_byte_o <= 8'h00;
                tx_en_o <= 1;

                // cpubus_trace_reg <= 40'h12_34_56_78_9A;

                if (rx_byte_i[3:0] == CMD_READTRACEREG)
                begin
                    // Handle READ CPU TRACE REG command
                    //
                    // check options:
                    trb_clear <= rx_byte_i[5];          // Clear trace buffer.
                    // first data byte -> return trace reg and buffer status: valid, ovf
                    tx_byte_o <= { 3'b000, ~stopped_cpu, trb_full, ~trb_empty, tracereg_ovf, 
                                   tracereg_valid | (rx_byte_i[4] && !trb_empty) };
                    tx_en_o <= 1;
                    // Only when the CPU is fully stopped, allow changing of the trace register
                    // by the host. Otherwise we might get race conditions between host reading out
                    // the trace register (it is a shift reg.) and ICD writing new trace data 
                    // during the release_wr state.
                    if (stopped_cpu)
                    begin
                        // reset the status bits
                        tracereg_ovf <= 0;
                        tracereg_valid <= 0;
                        // load trace reg from buffer?
                        if (rx_byte_i[4] && !trb_empty)
                        begin
                            cpubus_trace_reg <= trb_rport;
                            trb_rdeq <= 1;              // Dequeue a word from the trace buffer into shift register.
                        end
                        // sample trace reg from the current CPU state?
                        if (rx_byte_i[6])
                        begin
                            cpubus_trace_reg <= cpubus_trace_i;
                        end
                    end
                end

                //  *              0x0         GETSTATUS
                //  *                          TX:2nd byte = dummy
                //  *                          TX:3rd byte = status of CPU / ICD
                //  *                                  [0]    TRACE-REG VALID
                //  *                                  [1]    TRACE-REG OVERFLOWED
                //  *                                  [2]    TRACE-BUF NON-EMPTY
                //  *                                  [3]    TRACE-BUF FULL
                //  *                                  [4]    CPU-RUNNING? If yes (1), then trace register reading is not allowed (returns dummy)!!
                //  *                                          reserved = [7:5]
                //  *                          TX:4th byte = trace REGISTER contents: LSB byte (just read, not shifting!!)
                if (rx_byte_i[3:0] == CMD_GETSTATUS)
                begin
                    // Handle CMD_GETSTATUS command.
                    // Setup TX:3rd byte (1st data byte out)
                    tx_byte_o <= { 3'b000, ~stopped_cpu, trb_full, ~trb_empty, tracereg_ovf, 
                                   tracereg_valid };
                    tx_en_o <= 1;

                    // if the trace reg is NOT VALID (i.e. EMPTY)
                    //      AND the cpu is STOPPED => then we SAMPLE the cpu state into the trace reg
                    //                              and make it available in the next spi read byte.
                    if (!tracereg_valid && stopped_cpu)
                    begin
                        cpubus_trace_reg <= cpubus_trace_i;
                    end
                end
            end

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
                    cpu_force_irqn_o <= ~rx_byte_i[1];
                    cpu_force_nmin_o <= ~rx_byte_i[2];
                    cpu_force_abortn_o <= ~rx_byte_i[3];
                    cpu_block_irq_o <= rx_byte_i[4];
                    cpu_block_nmi_o <= rx_byte_i[5];
                    cpu_block_abort_o <= rx_byte_i[6];
                    counter <= counter + 1;
                end
            end

            if ((icd_cmd[3:0] == CMD_GETSTATUS)  && rx_db_en_i)
            begin
                // 2nd and further data bytes -> provide trace buffer (LSB 8 bits)
                tx_byte_o <= cpubus_trace_reg[7:0];
                tx_en_o <= 1;
                // do not shift;
            end

            if ((icd_cmd[3:0] == CMD_READTRACEREG)  && rx_db_en_i)
            begin
                // 2nd and further data bytes -> provide trace buffer (LSB 8 bits)
                tx_byte_o <= cpubus_trace_reg[7:0];
                tx_en_o <= 1;
                // avoid any race conditions by shifting out the trace reg only while the CPU is stopped!
                if (stopped_cpu)
                begin
                    // shift the trace buffer right by 8 bits - prepare for next access
                    cpubus_trace_reg <= { 8'h00, cpubus_trace_reg[CPUTRACE_WIDTH-1:8] };
                end
            end

            if ((icd_cmd[3:0] == CMD_FORCECDB) && rx_db_en_i)
            begin
                // Handle FORCE CPU DB command
                //
                if (counter == 0)
                begin
                    // decode command bits
                    force_cpu_db_o <= icd_cmd[4];
                    ignore_cpu_writes_o <= icd_cmd[5];
                    // first data byte -> set cpu db output
                    cpu_db_forced_o <= rx_byte_i;
                    counter <= counter + 1;
                end
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

            // request to stop the CPU
            if (cpu_stop_i)
            begin
                run_cpu <= 0;
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

            // finishing a cpu cycle?
            if (release_cs_i)
            begin
                // disable of forcing CPU opcode
                force_cpu_db_o <= 0;
                ignore_cpu_writes_o <= 0;
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
                    // 
                    if (cpu_reset_i)
                    begin
                        startup_fsm_r <= STARTUP_INIT;
                    end
                end
            endcase
        end
    end

    // Enqueue to the trace buffer only when the trace register is already full (valid).
    // The (previous contents of) cpubus_trace_reg is inserted into the trace buffer,
    // making place for the new trace info.
    // New trace info is always inserted into the trace register.
    assign trb_wenq = tracereg_valid && trace_catch_i;

endmodule
