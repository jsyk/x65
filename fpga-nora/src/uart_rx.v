/* Copyright (c) 2023-2024 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * UART RX port
 */
module uart_rx 
(
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    // Prescaled rx-clock
    input           uart_cken_i,              // 16x the UART transmit baud-rate, 1T pulses
    // Parity configuration. Should be held constant normally, and changed just in idle.
    input           parity_type_i,          // which type of parity bit to expect: 0=even, 1=odd.
    input           parity_en_i,            // enable the receive of parity bit (1), or no parity (0)
    // Data received
    output wire [7:0] rx_byte_o,          // received data byte
    output reg      rx_en_o,            // flag: got byte
    output reg      frame_err_o,        // 1T flag indicates framing error (hi start bit or low stop bit)
    output reg      parity_err_o,       // 1T flag indicates parity error (if parity is enabled)
    // Input RX signal from the FPGA pin
    input           rx_pin_i
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
    reg [7:0]       rxbuf_r;
    // parity calc bit
    reg             parity_r;

    // ticks at the baudrate
    wire baud_tick  = (prescaler_r == PRECS_TOP) && uart_cken_i;
    /*
    UART RXD:
    ----  START-BIT  ----D0----- ----D1----- ----D2----- ----D3----- ----D4----- ----D5----- ----D6----- ----D7----- ----------- --------
        |___________|___________|___________|___________|___________|___________|___________|___________|___________| STOP-BIT  |

    baud_tick:
    __________|___________|___________|___________|___________|___________|___________|___________|___________|___________|___________|

    fsm_state_r / fsm_bit_r:
    IDLE|STARTBIT
               DATABITS/0 |DATABITS/1 |DATABITS/2 |DATABITS/3 |DATABITS/4 |DATABITS/5 |DATABITS/6 |DATABITS/7 |STOPBIT    |IDLE
    */

    // synchronized rx_pin
    reg             rxpin_r;
    always @(posedge clk)  rxpin_r <= rx_pin_i;

    always @(posedge clk)
    begin
        frame_err_o <= 0;
        parity_err_o <= 0;
        rx_en_o <= 0;

        if (!resetn)
        begin
            // in reset
            prescaler_r <= 0;
            fsm_state_r <= IDLE;
            fsm_bit_r <= 0;
            rxbuf_r <= 0;
            parity_r <= 0;
        end else begin
            // normal operation;

            // generate prescaler counter
            if (uart_cken_i)
            begin
                prescaler_r <= prescaler_r + 1;
            end

            case (fsm_state_r)
                IDLE:
                begin
                    // no transmission in progress.
                    // detect the start bit
                    if (rxpin_r == 0)
                    begin
                        // START BIT
                        // start the prescaler WITH 50% PHASE
                        prescaler_r <= PRECS_TOP/2;
                        // go to
                        fsm_state_r <= STARTBIT;
                    end
                end

                STARTBIT:
                begin
                    if (baud_tick)
                    begin
                        // we are now in the middle of the start-bit
                        if (rxpin_r == 0)
                        begin
                            // start-bit correct; continue to the data bit
                            fsm_state_r <= DATABITS;
                            fsm_bit_r <= 0;
                            parity_r <= parity_type_i;
                        end else begin
                            // incorrect start-bit
                            fsm_state_r <= IDLE;
                            frame_err_o <= 1;
                        end
                    end
                end

                DATABITS:
                begin
                    if (baud_tick)
                    begin
                        // we are now in the middle of DATABIT nr. fsm_bit_r
                        rxbuf_r <= { rxpin_r, rxbuf_r[7:1] };       // shift in
                        parity_r <= parity_r ^ rxpin_r;
                        fsm_bit_r <= fsm_bit_r + 1;

                        // enough bits?
                        if (fsm_bit_r == 7)
                        begin
                            // yes -> now expect the parity bit or stop bit
                            if (parity_en_i)
                            begin
                                // expect parity
                                fsm_state_r <= PARITYBIT;
                            end else begin
                                // expect stop bit
                                fsm_state_r <= STOPBIT;
                            end
                        end
                    end
                end

                PARITYBIT:
                begin
                    if (baud_tick)
                    begin
                        // we are now in the middle of PARITYBIT.
                        // compare the calculated parity with received parity
                        parity_r <= parity_r ^ rxpin_r;
                        // ... if they are identical (0-0 or 1-1), the result is parity_r=0 => ok.
                        // ... if they are different (0-1 or 1-0), the result is parity_r=1 => err.
                        // Proceed to stop-bit, where the parity is checked.
                        fsm_state_r <= STOPBIT;
                    end
                end

                STOPBIT:
                begin
                    if (baud_tick)
                    begin
                        // we are now in the middle of STOPBIT.
                        // Check what we get:
                        if (rxpin_r == 1)
                        begin
                            // 1 = a correct stop-bit.
                            // was parity requested?
                            if (parity_en_i)
                            begin
                                // yes, so check it
                                if (parity_r)
                                begin
                                    // =1: parity bit was wrong! (data is not passed out)
                                    parity_err_o <= 1;
                                end else begin
                                    // =0: parity bit was correct! Pass the data byte out.
                                    rx_en_o <= 1;
                                end
                            end else begin
                                // parity check was not requested. Pass the data byte out.
                                rx_en_o <= 1;
                            end
                        end else begin
                            // rxpin=0 = incorrect stop-bit! indicate a framing error (data is not passed out)
                            frame_err_o <= 1;
                        end
                        // in any case go to IDLE
                        fsm_state_r <= IDLE;
                    end
                    
                end

                default: 
                    fsm_state_r <= IDLE;
            endcase
        end
    end

    assign rx_byte_o = rxbuf_r;

endmodule
