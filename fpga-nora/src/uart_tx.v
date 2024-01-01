/* Copyright (c) 2023-2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * UART TX port
 */
module uart_tx 
(
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    // Prescaled tx-clock
    input           uart_cken_i,              // 16x the UART transmit baud-rate, 1T pulses
    // Parity configuration
    input           parity_type_i,          // which type of parity bit to transmit: 0=even, 1=odd.
    input           parity_en_i,            // enable the generation of parity bit (1), or no parity (0)
    // Data to send to the TXD
    input [7:0]     tx_byte_i,          // transmit data byte
    input           tx_en_i,            // flag: catch the transmit byte
    output          tx_ready_o,         // flag: it is possible to enqueue next tx byte now.
    // Output TX signal to the FPGA pin
    output reg      tx_pin_o,
    output reg      txde_o              // tx drive enable, active high
);
// IMPLEMENTATION
    // definition of fsm states:
    localparam IDLE = 0;
    localparam STARTBIT = 1;
    localparam DATABITS = 2;
    localparam PARITYBIT = 3;
    localparam STOPBIT = 4;

    // prescaler bit-length
    localparam PRESC_LEN = 4;
    localparam PRECS_TOP = 2**PRESC_LEN - 1;

    // prescaler- counts uart_cken_i
    reg [PRESC_LEN-1:0]       prescaler_r;
    // state machine
    reg [2:0]       fsm_state_r;
    reg [2:0]       fsm_bit_r;
    // tx shift buffer
    reg [7:0]       txbuf_r;
    // parity calc bit
    reg             parity_r;

    // ticks at the baudrate
    wire baud_tick  = (prescaler_r == PRECS_TOP) && uart_cken_i;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // in reset
            prescaler_r <= 0;
            fsm_state_r <= IDLE;
            fsm_bit_r <= 0;
            txbuf_r <= 0;
            parity_r <= 0;
            tx_pin_o <= 1;
            txde_o <= 0;
        end else begin
            // normal operation;

            // generate prescaler counter
            if (uart_cken_i)
            begin
                prescaler_r <= prescaler_r + 1;
            end

            case (fsm_state_r)
                IDLE:       // nothing in progress
                begin
                    // drive idle to the uart tx
                    tx_pin_o <= 1;
                    txde_o <= 0;
                    // check if req to start the transmission
                    if (tx_en_i)        // req to start the transmission?
                    begin
                        // yes -> get the tx byte
                        txbuf_r <= tx_byte_i;
                        fsm_state_r <= STARTBIT;
                        prescaler_r <= 0;
                        tx_pin_o <= 0;      // drive START BIT = 0
                        txde_o <= 1;
                        parity_r <= parity_type_i;      // init parity bit
                    end
                end
                
                STARTBIT:
                begin
                    if (baud_tick)          // end of start-bit
                    begin
                        fsm_state_r <= DATABITS;
                        fsm_bit_r <= 0;
                        tx_pin_o <= txbuf_r[0];     // drive BIT 0
                        parity_r <= parity_r ^ txbuf_r[0];
                        txbuf_r <= { 1'b0, txbuf_r[7:1] };      // shift right
                    end
                end
                
                DATABITS:
                begin
                    if (baud_tick)
                    begin
                        // count next bit
                        fsm_bit_r <= fsm_bit_r + 1;
                        // ending the last bit?
                        if (fsm_bit_r == 7)
                        begin
                            // yes -> now drive parity or stop bit
                            if (parity_en_i)
                            begin
                                // parity output enabled -> drive the parity bit
                                tx_pin_o <= parity_r;
                                fsm_state_r <= PARITYBIT;
                            end else begin
                                // parity output not enabled -> drive the stop bit
                                tx_pin_o <= 1;
                                fsm_state_r <= STOPBIT;
                            end
                        end else begin
                            // normal bit shifting
                            tx_pin_o <= txbuf_r[0];         // drive BIT n
                            parity_r <= parity_r ^ txbuf_r[0];
                            txbuf_r <= { 1'b0, txbuf_r[7:1] };      // shift right
                        end
                    end
                end

                PARITYBIT:
                begin
                    if (baud_tick)
                    begin
                        // end of parity bit -> drive stop bit = 1
                        fsm_state_r <= STOPBIT;
                        tx_pin_o <= 1;
                    end
                end

                STOPBIT:
                begin
                    if (baud_tick)
                    begin
                        // stop bit ended; continue the transmission with the next byte?
                        if (tx_en_i)
                        begin
                            // yes, there is a req to immediately start next byte;
                            txbuf_r <= tx_byte_i;
                            fsm_state_r <= STARTBIT;
                            tx_pin_o <= 0;      // drive START BIT = 0
                            parity_r <= parity_type_i;      // init parity bit
                        end else begin
                            // no request -> go to the idle state
                            fsm_state_r <= IDLE;
                            tx_pin_o <= 1;      // drive idle state
                        end
                    end
                end
                
                default:
                begin
                    fsm_state_r <= IDLE;
                end
            endcase
        end
    end

    // we are ready to accept next tx-byte just in the IDLE state or at the end of STOPBIT
    assign tx_ready_o = (fsm_state_r == IDLE) || ((fsm_state_r == STOPBIT) && baud_tick);

endmodule
