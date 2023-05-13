/**
 * System Management Controller defined by CX16
 * 
 */
module smc (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // I2C bus
    input           I2C_SDA_i,
    output          I2C_SDADR0_o,
    input           I2C_SCL_i
    //
);
    // IMPLEMENTATION

    wire      devsel;           // the device is selected, ongoing transmission for the SLAVE_ADDRESS
    wire      rw_bit;           // Read/nWrite bit, only valid when devsel_o=1
    wire [7:0]  rxbyte;          // the received byte for device
    wire        rxbyte_v;         // valid received byte (for 1T) for Write transfers
    reg  [7:0]  txbyte;           // the next byte to transmit from device; shall be valid anytime devsel_o=1 && rw_bit_o=1
    wire       txbyte_deq;       // the txbyte has been consumed (1T)
    // output reg      tx_nacked_o         // master NACKed the last byte!

    i2c_slave i2cslv 
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

    always @(posedge clk6x) 
    begin
        if (!resetn)
        begin
            txbyte <= 8'hFF;
        end else begin
            
        end
        
    end

endmodule

