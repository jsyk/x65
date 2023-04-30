/**
 * Simplified VIA (65C22) - provides basic GPIO and Timer service.
 * Unimplemented features: serial and handshake functions, CA/CB pins.
 * 
 * TBD: implement the timer functionality!!
 */
module simple_via (
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // NORA slave interface - internal devices
    input [3:0]     slv_addr_i,
    input  [7:0]    slv_datawr_i,     // write data = available just at the end of cycle!!
    input           slv_datawr_valid,      // flags nora_slv_datawr_o to be valid
    output reg [7:0]    slv_datard_o,
    input           slv_req_i,
    input           slv_rwn_i,
    // GPIO interface, 2x 8-bit
    output reg [7:0] gpio_ora,          // ORA = output reg A
    output reg [7:0] gpio_orb,
    input [7:0]     gpio_ira,           // IRA = input reg A
    input [7:0]     gpio_irb,
    output reg [7:0] gpio_ddra,         // DDRA = data direction reg A; 0 = input, 1 = output.
    output reg [7:0] gpio_ddrb,
    //
    input           phi2
);
    // IMPLEMENTATION

    parameter REG_ORB_IRB = 4'h0;
    parameter REG_ORA_IRA = 4'h1;
    parameter REG_DDRB = 4'h2;
    parameter REG_DDRA = 4'h3;
    parameter REG_T1CL = 4'h4;
    parameter REG_T1CH = 4'h5;
    parameter REG_T1LL = 4'h6;
    parameter REG_T1LH = 4'h7;
    parameter REG_T2CL = 4'h8;
    parameter REG_T2CH = 4'h9;
    parameter REG_SR = 4'hA;
    parameter REG_ACR = 4'hB;
    parameter REG_PCR = 4'hC;
    parameter REG_IFR = 4'hD;
    parameter REG_IER = 4'hE;
    parameter REG_ORA_IRA_NOHS = 4'hF;

    always @(posedge clk6x) 
    begin
        // slv_datard_o <= 8'h00;

        if (!resetn)
        begin   // sync reset
            gpio_ora <= 8'h00;
            gpio_orb <= 8'h00;
            gpio_ddra <= 8'h00;         // all inputs
            gpio_ddrb <= 8'h00;         // all inputs
        end else begin
            if (slv_req_i)
            begin  // slave selected.
                if (slv_rwn_i)
                begin 
                    // reading
                    case (slv_addr_i[3:0])
                        REG_ORB_IRB : //  = 4'h0;
                            slv_datard_o <= gpio_irb;
                        
                        REG_ORA_IRA, REG_ORA_IRA_NOHS : //  = 4'h1;  4'hF
                            slv_datard_o <= gpio_ira;
                        
                        REG_DDRB : //  = 4'h2;
                            slv_datard_o <= gpio_ddrb;
                        
                        REG_DDRA : //  = 4'h3;
                            slv_datard_o <= gpio_ddra;

                        // REG_T1CL : //  = 4'h4;
                        // REG_T1CH : //  = 4'h5;
                        // REG_T1LL : //  = 4'h6;
                        // REG_T1LH : //  = 4'h7;
                        // REG_T2CL : //  = 4'h8;
                        // REG_T2CH : //  = 4'h9;

                        REG_SR : //  = 4'hA;
                            slv_datard_o <= 8'h00;      // SR not implemented!

                        // REG_ACR : //  = 4'hB;

                        REG_PCR : //  = 4'hC;
                            slv_datard_o <= 8'h00;      // PCR not implemented!
                        
                        // REG_IFR : //  = 4'hD;
                        // REG_IER : //  = 4'hE;
                        default: 
                            slv_datard_o <= 8'h00;      // register not implemented!
                    endcase
                end
                if (!slv_rwn_i && slv_datawr_valid)
                begin
                    // writing
                    case (slv_addr_i[3:0])
                        REG_ORB_IRB : //  = 4'h0;
                            gpio_orb <= slv_datawr_i;
                        
                        REG_ORA_IRA, REG_ORA_IRA_NOHS : //  = 4'h1;  4'hF
                            gpio_ora <= slv_datawr_i;
                        
                        REG_DDRB : //  = 4'h2;
                            gpio_ddrb <= slv_datawr_i;

                        REG_DDRA : //  = 4'h3;
                            gpio_ddra <= slv_datawr_i;
                        
                        // REG_T1CL : //  = 4'h4;
                        // REG_T1CH : //  = 4'h5;
                        // REG_T1LL : //  = 4'h6;
                        // REG_T1LH : //  = 4'h7;
                        // REG_T2CL : //  = 4'h8;
                        // REG_T2CH : //  = 4'h9;

                        // REG_SR : //  = 4'hA;
                        // REG_ACR : //  = 4'hB;
                        // REG_PCR : //  = 4'hC;
                        // REG_IFR : //  = 4'hD;
                        // REG_IER : //  = 4'hE;
                        // default: 
                    endcase
                end
            end
        end
        
    end



endmodule
