/**
 * System Management Controller defined by CX16.
 * It primarily responds on I2C bus as the slave device at address 0x42.
 * It provides these registers over I2C:
 *      0x07		Read from keyboard buffer
 *      0x18		Read ps2 (keyboard) status
 *      0x19	    00..FF	Send ps2 command
 *      0x21		Read from mouse buffer     <- TBD, not implemented yet here!!
 *
 */
module smc (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // I2C bus (slave device)
    input           I2C_SDA_i,
    output          I2C_SDADR0_o,
    input           I2C_SCL_i,
    // PS2 Keyboard port
    input           PS2K_CLK,
    input           PS2K_DATA,
    output          PS2K_CLKDR,
    output          PS2K_DATADR

);
    // IMPLEMENTATION

    // I2C bus interface signals
    wire        devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    wire        rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    wire [7:0]  rxbyte;          // the received byte for device
    wire        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    wire [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    wire        txbyte_deq;       // the txbyte has been consumed (1T)
    // output reg      tx_nacked_o         // master NACKed the last byte!
    // reg  [1:0]  byteidx;

    i2c_slave #(.SLAVE_ADDRESS(8'h84))
    i2cslv 
    (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        // I2C bus
        .I2C_SDA_i (I2C_SDA_i),
        .I2C_SDADR0_o (I2C_SDADR0_o),
        .I2C_SCL_i (I2C_SCL_i),
        // Device interface
        .devsel_o (devsel),           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
        .rw_bit_o (rw_bit),           // Read/nWrite bit, only valid when devsel_o=1
        .rxbyte_o (rxbyte),          // the received byte for device
        .rxbyte_v_o (rxbyte_v),         // valid received byte (for 1T) for Write transfers
        .txbyte_i (txbyte),           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
        .txbyte_deq_o (txbyte_deq)       // the txbyte has been consumed (1T)
        // .tx_nacked_o (open)         // master NACKed the last byte!
    );


    // generate 1us pulses for PS2 port
    wire         ck1us;
    
    pulser pulser_1us
    (
        .clk6x (clk6x),       // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us)
    );

    ps2_kbd_host kbd (
        // Global signals
        .clk6x (clk6x),      // 48MHz
        .resetn (resetn),     // sync reset
        .ck1us (ck1us),      // 1us pulses
        // SMC interface
        .devsel_i (devsel),           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
        .rw_bit_i (rw_bit),           // Read/nWrite bit, only valid when devsel_i=1
        .rxbyte_i (rxbyte),          // the received byte for device
        .rxbyte_v_i (rxbyte_v),         // valid received byte (for 1T) for Write transfers
        .txbyte_o (txbyte),           // the next byte to transmit from device; shall be valid anytime devsel_i=1 && rw_bit_i=1
        .txbyte_deq_i (txbyte_deq),       // the txbyte has been consumed (1T)
        // PS2 Keyboard port - FPGA pins
        .PS2K_CLK (PS2K_CLK),
        .PS2K_DATA (PS2K_DATA),
        .PS2K_CLKDR (PS2K_CLKDR),         // 1=drive PS2K_CLK to zero (L)
        .PS2K_DATADR (PS2K_DATADR)         // 1=drive PS2K_DATA to zero (L)
    );

endmodule
