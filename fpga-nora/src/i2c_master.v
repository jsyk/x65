/**
 * I2C Master
 */
module i2c_master #(
    parameter SCLPREDIV = 480
) (
    // Global signals
    input           clk,        // 48MHz
    input           resetn,     // sync reset
    // I2C bus
    input           I2C_SDA_i,
    output reg      I2C_SDADR0_o,       // 1 will drive SDA low
    input           I2C_SCL_i,
    output reg      I2C_SCLDR0_o,       // 1 will drive SCL low
    // Host interface
    input [2:0]     cmd_i,      // command
    output [7:0]    status_o,     // bus operation in progress
    input [7:0]     data_wr_i,  // data for transmitt
    output reg [7:0] data_rd_o      // data received
);
    // IMPLEMENTATION

    // ----------------------------------------------------------------
    // definition of commands
    localparam CMD_NOOP             = 3'b000;
    localparam CMD_STARTADDR        = 3'b001;   // send START + WRBYTE_RDACK
    localparam CMD_WRBYTE_RDACK     = 3'b010;   // send BYTE + read ACK-bit in D0
    localparam CMD_RDBYTE           = 3'b011;   // recv BYTE
    localparam CMD_WRACK            = 3'b100;   // send ACK (0)
    localparam CMD_WRNACK           = 3'b101;   // send NACK (1)
    localparam CMD_STOP             = 3'b111;   // generate STOP, release bus

    // ----------------------------------------------------------------
    // decouple inputs
    reg             i2c_sdai_r;
    reg             i2c_scli_r;

    always @(posedge clk)
    begin
        i2c_sdai_r <= I2C_SDA_i;
        i2c_scli_r <= I2C_SCL_i;
    end

    // ----------------------------------------------------------------
    // generate clock pulses at the 100kHz speed from the main clock
    reg [8:0]       prediv_r;
    wire            rst_prediv;
    reg             prediv_pulse_r;

    always @(posedge clk)
    begin
        if (!resetn || rst_prediv)
        begin
            prediv_r <= 0;
            prediv_pulse_r <= 0;
        end else begin
            prediv_r <= prediv_r + 1;
            prediv_pulse_r <= 0;

            if (prediv_r == SCLPREDIV)
            begin
                prediv_r <= 0;
                prediv_pulse_r <= 1;
            end
        end
    end

    // ----------------------------------------------------------------
    // states of the main FSM
    localparam IDLE     = 4'h0;         // not busy, can accept a new command
    //     START condition
    localparam START0   = 4'hC;         // START: SDA let high, tick -> START01
    localparam START01  = 4'hD;         // START: SCL let high, tick -> START1
    localparam START1   = 4'h1;         // START: SDA pulled low, tick, -> START2
    localparam START2   = 4'h2;         // START: SCL pulled low, tick, -> BIT_W0
    //     BIT/BYTE SENDING
    localparam BIT_W0   = 4'h3;         // Write Bit ph-0: SDA output (hi/lo), tick, -> BIT_W1
    localparam BIT_W1   = 4'h4;         // Write Bit ph-1: SCL to high, tick, -> BIT_W2
    localparam BIT_W2   = 4'h5;         // Write Bit ph-2: SCL to low, tick, -> BIT_W0 or BIT_R0 (ack) or IDLE (wack)
    //     BIT/BYTE RECV
    localparam BIT_R0   = 4'h6;         // Read bit ph-0: SDA out hi (dont drive), tick, -> BIT_R1
    localparam BIT_R1   = 4'h7;         // Read bit ph-1: SCL to high, tick, Shift-in data bit, -> BIT_R2
    localparam BIT_R2   = 4'h8;         // Read bit ph-1: SCL to low, tick, -> BIT_R0 or IDLE
    //      STOP condition
    localparam STOP0    = 4'h9;         // STOP: SDA low, tick, -> STOP1
    localparam STOP1    = 4'hA;         // STOP: SCL let high, tick, -> STOP2
    localparam STOP2    = 4'hB;         // STOP: SDA let high, tick, -> IDLE


    // FSM states
    reg [3:0]   state_r;
    // data buffer / shift register (MSB first)
    reg [7:0]   databuf_r;
    // bit counter
    reg [2:0]   bitcounter_r;
    // flag: is this ack-bit writing?
    reg         wack_r;
    // are we busy?
    reg         busy_r;
    // the flag indicates that the timeout has been reached
    reg         timeout_flag_r;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            state_r <= IDLE;
            databuf_r <= 0;
            data_rd_o <= 0;
            bitcounter_r <= 0;
            wack_r <= 0;
            busy_r <= 0;
            // do not drive I2C bus
            I2C_SDADR0_o <= 0;
            I2C_SCLDR0_o <= 0;
        end else begin
            // based on fsm state...
            case (state_r)
                IDLE:       // no action ongoing, can accept a new command
                begin
                    // indicate we are  busy
                    busy_r <= 1;
                    // check if new command?
                    case (cmd_i)
                        CMD_NOOP:       // no command->stay in idle
                        begin
                            wack_r <= 0;
                            busy_r <= 0;
                        end

                        CMD_STARTADDR:  // generate START condition and write address byte and read ack
                        begin
                            wack_r <= 0;
                            state_r <= START0;
                            databuf_r <= data_wr_i;
                            bitcounter_r <= 7;
                        end

                        CMD_WRBYTE_RDACK:       // write byte and read ack in D0
                        begin
                            wack_r <= 0;
                            state_r <= BIT_W0;
                            databuf_r <= data_wr_i;
                            bitcounter_r <= 7;
                        end

                        CMD_RDBYTE:         // read byte
                        begin
                            state_r <= BIT_R0;
                            bitcounter_r <= 7;
                        end

                        CMD_WRACK:          // write ack bit (0)
                        begin
                            wack_r <= 1;
                            state_r <= BIT_W0;
                            bitcounter_r <= 0;
                            databuf_r <= 0;
                        end

                        CMD_WRNACK:          // write Nack bit (1)
                        begin
                            wack_r <= 1;
                            state_r <= BIT_W0;
                            bitcounter_r <= 0;
                            databuf_r <= 8'hFF;
                        end

                        CMD_STOP:           // generate STOP condition
                        begin
                            state_r <= STOP0;
                        end
                    endcase
                end

                START0:     // START: SDA let high, tick -> START01
                begin
                    I2C_SDADR0_o <= 0;
                    // wait for i2c clock-tick && SDA is high
                    if (prediv_pulse_r && i2c_sdai_r)
                    begin
                        state_r <= START01;
                    end else if (timeout_flag_r) 
                    begin
                        // timeout reached!! -> reset the FSM to the IDLE state
                        state_r <= IDLE;
                    end
                end

                START01:    // START: SCL let high, tick -> START1
                begin
                    I2C_SCLDR0_o <= 0;
                    // wait for i2c clock-tick && SCL is high
                    if (prediv_pulse_r && i2c_scli_r)
                    begin
                        state_r <= START1;
                    end else if (timeout_flag_r) 
                    begin
                        // timeout reached!! -> reset the FSM to the IDLE state
                        state_r <= IDLE;
                    end
                end

                START1:     // first part of START: SDA pulled low
                begin
                    // drive SDA low
                    I2C_SDADR0_o <= 1;
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        state_r <= START2;
                    end
                end

                START2:     // second part of START: SCL pulled low
                begin
                    // drive SCL low
                    I2C_SCLDR0_o <= 1;
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        // START condition done: SCL, SDA are low; 
                        // and a tick has passed!
                        // Then send the address byte
                        state_r <= BIT_W0;
                    end
                end

                BIT_W0:     // Write Bit ph-0: SDA output (hi/lo), tick
                begin
                    // drive SDA according to data bit
                    I2C_SDADR0_o <= ~(databuf_r[7]);
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        // SDA value set done, ticked
                        state_r <= BIT_W1;
                    end
                end

                BIT_W1:     // Write Bit ph-1: SCL to high, tick
                begin
                    // SCL to high (stop driving zero)
                    I2C_SCLDR0_o <= 0;
                    // wait for i2c clock-tick && SCL is high
                    if (prediv_pulse_r && i2c_scli_r)
                    begin
                        // SCL is high, ticked
                        state_r <= BIT_W2;
                    end else if (timeout_flag_r) 
                    begin
                        // timeout reached!! -> reset the FSM to the IDLE state
                        state_r <= IDLE;
                    end
                end

                BIT_W2:     // Write Bit ph-2: SCL to low, tick
                begin
                    // drive SCL to low
                    I2C_SCLDR0_o <= 1;
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        // SCL is low, ticked
                        // Shift data buffer to the left
                        databuf_r <= { databuf_r[6:0], 1'b0 };
                        // was this ACK bit write?
                        if (wack_r)
                        begin
                            // yes -> we're done
                            state_r <= IDLE;
                        end else begin
                            // was not ack;
                            // all bits done?
                            if (bitcounter_r == 0)
                            begin
                                // yes!
                                // Read the ACK bit
                                bitcounter_r <= 0;      // we get just 1 bit
                                state_r <= BIT_R0;
                            end else begin
                                // decrement the remaining number of bits to send
                                bitcounter_r <= bitcounter_r - 1;
                                state_r <= BIT_W0;
                            end
                        end
                    end
                end

                BIT_R0:         // Read bit ph-0: SDA out hi (dont drive), tick
                begin
                    // SDA dont drive (let high)
                    I2C_SDADR0_o <= 0;
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        // tick
                        state_r <= BIT_R1;
                    end
                end

                BIT_R1:         // Read bit ph-1: SCL to high, tick, Shift-in data bit
                begin
                    // SCL dont drive -> high
                    I2C_SCLDR0_o <= 0;
                    // wait for i2c clock-tick && SCL is high
                    if (prediv_pulse_r && i2c_scli_r)
                    begin
                        // tick;
                        // shift-in the data bit
                        databuf_r <= { databuf_r[6:0], i2c_sdai_r };
                        state_r <= BIT_R2;
                    end else if (timeout_flag_r) 
                    begin
                        // timeout reached!! -> reset the FSM to the IDLE state
                        state_r <= IDLE;
                    end
                end

                BIT_R2:     // Read bit ph-1: SCL to low, tick
                begin
                    // SCL to low
                    I2C_SCLDR0_o <= 1;
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        // tick;
                        // all bits done?
                        if (bitcounter_r == 0)
                        begin
                            // yes!
                            // Done, go to the idle
                            data_rd_o <= databuf_r;
                            state_r <= IDLE;
                        end else begin
                            // decrement the remaining number of bits to send
                            bitcounter_r <= bitcounter_r - 1;
                            state_r <= BIT_R0;
                        end
                    end                    
                end

                STOP0:      // STOP: SDA low, tick
                begin
                    // low SDA
                    I2C_SDADR0_o <= 1;
                    // low SCL (should already be)
                    I2C_SCLDR0_o <= 1;
                    // wait for i2c clock-tick
                    if (prediv_pulse_r)
                    begin
                        // tick;
                        state_r <= STOP1;
                    end
                end

                STOP1:      // STOP: SCL let high, tick
                begin
                    // dont drive SCL, let high
                    I2C_SCLDR0_o <= 0;
                    // wait for i2c clock-tick && SCL is high
                    if (prediv_pulse_r && i2c_scli_r)
                    begin
                        // tick;
                        state_r <= STOP2;
                    end else if (timeout_flag_r) 
                    begin
                        // timeout reached!! -> reset the FSM to the IDLE state
                        state_r <= IDLE;
                    end
                end

                STOP2:      // STOP: SDA let high, tick
                begin
                    // dont drive SDA (let high)
                    I2C_SDADR0_o <= 0;
                    // wait for i2c clock-tick && SDA is high
                    if (prediv_pulse_r && i2c_sdai_r)
                    begin
                        // tick;
                        state_r <= IDLE;
                    end else if (timeout_flag_r) 
                    begin
                        // timeout reached!! -> reset the FSM to the IDLE state
                        state_r <= IDLE;
                    end
                end

                default:
                begin
                    state_r <= IDLE;
                end 
            endcase
        end
        
    end

    // ----------------------------------------------------------------
    // Timeout counter and generator: if the bus is stuck, we need to reset
    // the FSM to the IDLE state to avoid hanging the system
    // and inform the host about the error (status_o[6] = 1).

    // The timer counts the number of prediv_pulses, and if it reaches
    // the top value (255), the timeout is indicated.
    reg [7:0]      timeout_cnt_r;

    // The timeout counter is cleared whenever the FSM changes its state,
    // which means there is some progress.
    reg [3:0]       state_last_r;


    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // reset the timeout counter
            timeout_cnt_r <= 0;
            state_last_r <= IDLE;
            timeout_flag_r <= 0;
        end else begin
            // update the state
            state_last_r <= state_r;

            // reset the timeout flag when we are leaving the IDLE state
            if (state_last_r == IDLE && state_r != IDLE)
            begin
                timeout_flag_r <= 0;
            end

            // check if the state has changed
            if (state_r != state_last_r)
            begin
                // yes -> all is well -> reset the timeout counter
                timeout_cnt_r <= 0;
            end else begin
                // no -> increment the timeout counter at each prediv_pulse
                if (prediv_pulse_r)
                begin
                    // increment the counter
                    timeout_cnt_r <= timeout_cnt_r + 1;

                    // check if the timeout is reached
                    if (timeout_cnt_r == 255)
                    begin
                        // timeout reached
                        timeout_flag_r <= 1;
                    end
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // reset the pre-divider as soon the IDLE state is reached
    // so that the next command always starts with clean timing
    assign rst_prediv = (state_r == IDLE);

    // ----------------------------------------------------------------
    // core status output, 8 bits
    assign status_o = { busy_r, timeout_flag_r, i2c_sdai_r, i2c_scli_r, state_r };

endmodule
