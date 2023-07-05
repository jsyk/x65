/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. 
 */
module ps2_scancode_to_keycode (
    // Global signals
    input           clk,        // 48MHz
    input           resetn,     // sync reset
    // PS2 scancode from the keyboard ps2_port
    input [7:0]     ps2k_scancode_i,        // received byte from PS2 port
    input           ps2k_scodevalid_i,   // validity flag of the PS2 port received byte
    // PS2 key code
    output reg [7:0]  ps2k_keycode_o,       // translated keycode
    output reg      ps2k_kcvalid_o          // validity flag of keycode
);

    reg [7:0] basic_keycode;

    // (pre-compute) the mapping from simple PS2 scancode to key code
    // assuming no extended code prefix was received
    always @(posedge clk)
    begin
        basic_keycode <= 8'd0;
        case (ps2k_scancode_i)
            8'h01: basic_keycode <= 8'd120;
            8'h02: basic_keycode <= 8'd0;
            8'h03: basic_keycode <= 8'd116;
            8'h04: basic_keycode <= 8'd114; 
            8'h05: basic_keycode <= 8'd112; 
            8'h06: basic_keycode <= 8'd113; 
            8'h07: basic_keycode <= 8'd123; 
            8'h08: basic_keycode <= 8'd0;

            8'h09: basic_keycode <= 8'd121;
            8'h0A: basic_keycode <= 8'd119; 
            8'h0B: basic_keycode <= 8'd117; 
            8'h0C: basic_keycode <= 8'd115; 
            8'h0D: basic_keycode <= 8'd16;
            8'h0E: basic_keycode <= 8'd1;
            8'h0F: basic_keycode <= 8'd0; 
            8'h10: basic_keycode <= 8'd0;

            8'h11: basic_keycode <= 8'd60;
            8'h12: basic_keycode <= 8'd44;
            8'h13: basic_keycode <= 8'd0;
            8'h14: basic_keycode <= 8'd58;
            8'h15: basic_keycode <= 8'd17;
            8'h16: basic_keycode <= 8'd2;
            8'h17: basic_keycode <= 8'd0; 
            8'h18: basic_keycode <= 8'd0;

            8'h19: basic_keycode <= 8'd0;
            8'h1A: basic_keycode <= 8'd46; 
            8'h1B: basic_keycode <= 8'd32; 
            8'h1C: basic_keycode <= 8'd31; 
            8'h1D: basic_keycode <= 8'd18; 
            8'h1E: basic_keycode <= 8'd3;
            8'h1F: basic_keycode <= 8'd0; 
            8'h20: basic_keycode <= 8'd0;

            8'h21: basic_keycode <= 8'd48;
            8'h22: basic_keycode <= 8'd47; 
            8'h23: basic_keycode <= 8'd33; 
            8'h24: basic_keycode <= 8'd19; 
            8'h25: basic_keycode <= 8'd5; 
            8'h26: basic_keycode <= 8'd4;  
            8'h27: basic_keycode <= 8'd0; 
            8'h28: basic_keycode <= 8'd0;

            8'h29: basic_keycode <= 8'd61;
            8'h2A: basic_keycode <= 8'd49; 
            8'h2B: basic_keycode <= 8'd34;
            8'h2C: basic_keycode <= 8'd21; 
            8'h2D: basic_keycode <= 8'd20; 
            8'h2E: basic_keycode <= 8'd6; 
            8'h2F: basic_keycode <= 8'd0; 
            8'h30: basic_keycode <= 8'd0;

            8'h31: basic_keycode <= 8'd51;
            8'h32: basic_keycode <= 8'd50;
            8'h33: basic_keycode <= 8'd36; 
            8'h34: basic_keycode <= 8'd35; 
            8'h35: basic_keycode <= 8'd22; 
            8'h36: basic_keycode <= 8'd7; 
            8'h37: basic_keycode <= 8'd0; 
            8'h38: basic_keycode <= 8'd0;

            8'h39: basic_keycode <= 8'd0;
            8'h3A: basic_keycode <= 8'd52; 
            8'h3B: basic_keycode <= 8'd37; 
            8'h3C: basic_keycode <= 8'd23; 
            8'h3D: basic_keycode <= 8'd8; 
            8'h3E: basic_keycode <= 8'd9; 
            8'h3F: basic_keycode <= 8'd0; 
            8'h40: basic_keycode <= 8'd0;

            8'h41: basic_keycode <= 8'd53; 
            8'h42: basic_keycode <= 8'd38; 
            8'h43: basic_keycode <= 8'd24; 
            8'h44: basic_keycode <= 8'd25; 
            8'h45: basic_keycode <= 8'd11; 
            8'h46: basic_keycode <= 8'd10; 
            8'h47: basic_keycode <= 8'd0; 
            8'h48: basic_keycode <= 8'd0;

            8'h49: basic_keycode <= 8'd54;
            8'h4A: basic_keycode <= 8'd55; 
            8'h4B: basic_keycode <= 8'd39; 
            8'h4C: basic_keycode <= 8'd40; 
            8'h4D: basic_keycode <= 8'd26; 
            8'h4E: basic_keycode <= 8'd12; 
            8'h4F: basic_keycode <= 8'd0; 
            8'h50: basic_keycode <= 8'd0;

            8'h51: basic_keycode <= 8'd0;
            8'h52: basic_keycode <= 8'd41; 
            8'h53: basic_keycode <= 8'd0; 
            8'h54: basic_keycode <= 8'd27; 
            8'h55: basic_keycode <= 8'd13; 
            8'h56: basic_keycode <= 8'd0; 
            8'h57: basic_keycode <= 8'd0; 
            8'h58: basic_keycode <= 8'd30;

            8'h59: basic_keycode <= 8'd57; 
            8'h5A: basic_keycode <= 8'd43; 
            8'h5B: basic_keycode <= 8'd28; 
            8'h5C: basic_keycode <= 8'd0; 
            8'h5D: basic_keycode <= 8'd29;
            8'h5E: basic_keycode <= 8'd0;
            8'h5F: basic_keycode <= 8'd0; 
            8'h60: basic_keycode <= 8'd0;

            8'h61: basic_keycode <= 8'd45; 
            8'h62: basic_keycode <= 8'd0;
            8'h63: basic_keycode <= 8'd0; 
            8'h64: basic_keycode <= 8'd0; 
            8'h65: basic_keycode <= 8'd0; 
            8'h66: basic_keycode <= 8'd15; 
            8'h67: basic_keycode <= 8'd0; 
            8'h68: basic_keycode <= 8'd0;

            8'h69: basic_keycode <= 8'd93; 
            8'h6A: basic_keycode <= 8'd0; 
            8'h6B: basic_keycode <= 8'd92; 
            8'h6C: basic_keycode <= 8'd91;
            8'h6D: basic_keycode <= 8'd0; 
            8'h6E: basic_keycode <= 8'd0; 
            8'h6F: basic_keycode <= 8'd0; 
            8'h70: basic_keycode <= 8'd99;

            8'h71: basic_keycode <= 8'd104; 
            8'h72: basic_keycode <= 8'd98; 
            8'h73: basic_keycode <= 8'd97; 
            8'h74: basic_keycode <= 8'd102; 
            8'h75: basic_keycode <= 8'd96; 
            8'h76: basic_keycode <= 8'd110; 
            8'h77: basic_keycode <= 8'd90; 
            8'h78: basic_keycode <= 8'd122;

            8'h79: basic_keycode <= 8'd106; 
            8'h7A: basic_keycode <= 8'd103; 
            8'h7B: basic_keycode <= 8'd105; 
            8'h7C: basic_keycode <= 8'd100; 
            8'h7D: basic_keycode <= 8'd101; 
            8'h7E: basic_keycode <= 8'd125; 
            8'h7F: basic_keycode <= 8'd0; 
            8'h80: basic_keycode <= 8'd0;

            8'h81: basic_keycode <= 8'd0; 
            8'h82: basic_keycode <= 8'd0; 
            8'h83: basic_keycode <= 8'd118;

            default: basic_keycode <= 8'd0;
        endcase
    end

    
    reg [7:0] ext_keycode;

    // (pre-compute) the mapping from extended PS2 scancode to key code
    // assuming the extended code prefix was received
    always @(posedge clk)
    begin
        ext_keycode <= 8'd0;
        case (ps2k_scancode_i)
            8'h11:  // Right Alt
                ext_keycode <= 8'd62;
            8'h14:  // Right Ctrl
                ext_keycode <= 8'd64;
            8'h1f:  // Left GUI
                ext_keycode <= 8'd59;
            8'h27:  // Right GUI
                ext_keycode <= 8'd63;
            8'h2f:  // Menu key
                ext_keycode <= 8'd65;
            8'h69:  // End
                ext_keycode <= 8'd81;
            8'h70:  // Insert
                ext_keycode <= 8'd75;
            8'h71:  // Delete
                ext_keycode <= 8'd76;
            8'h6b:  // Left arrow
                ext_keycode <= 8'd79;
            8'h6c:  // Home
                ext_keycode <= 8'd80;
            8'h75:  // Up arrow
                ext_keycode <= 8'd83;
            8'h72:  // Down arrow
                ext_keycode <= 8'd84;
            8'h7d:  // Page up
                ext_keycode <= 8'd85;
            8'h7a:  // Page down
                ext_keycode <= 8'd86;
            8'h74:  // Right arrow
                ext_keycode <= 8'd89;
            8'h4a:  // KP divide
                ext_keycode <= 8'd95;
            8'h5a:  // KP enter
                ext_keycode <= 8'd108;
            8'h7c:  // KP PrtScr
                ext_keycode <= 8'd124;
            8'h15:  // Pause/Break
                ext_keycode <= 8'd126;
            default:
                ext_keycode <= 8'd0;
        endcase
    end


    // reg     flag_extcode;           // seen 0xE0  - ext code flag
    // reg     flag_breakcode;         // seen 0xF0  - break code flag
    // wire    keycode  = (flag_extcode) ? ext_keycode : basic_keycode;

    // FSM states for 'scancode_state'
    localparam START_NEW_SC = 4'h0;    // Start of new scan code
    localparam AFTER_BREAK = 4'h1;     // After 0xf0 (break code)
    localparam AFTER_EXT = 4'h2;       // After 0xe0 (extended code)
    localparam AFTER_EXT_BREAK = 4'h3;     // After 0xe0 0xf0 (extended break code)
    localparam PAUSE_1 = 4'h4;
    localparam PAUSE_2 = 4'h5;
    localparam PAUSE_3 = 4'h6;
    localparam PAUSE_4 = 4'h7;
    localparam PAUSE_5 = 4'h8;
    localparam PAUSE_6 = 4'h9;
    localparam PAUSE_7 = 4'hA;
    localparam Q_FROM_BASIC = 4'hB;      // output keycode from basic translation
    localparam Q_FROM_EXT = 4'hC;      // output keycode from basic translation

    reg [3:0]       scancode_state;
    reg             q_msb;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            // reset active
            // flag_breakcode <= 0;
            // flag_extcode <= 0;
            scancode_state <= START_NEW_SC;
            q_msb <= 0;
            ps2k_keycode_o <= 0;
            ps2k_kcvalid_o <= 0;
        end else begin
            ps2k_kcvalid_o <= 0;

            case (scancode_state)
                START_NEW_SC:
                begin
                    // receiving a valid scancode pro the PS2 port?
                    if (ps2k_scodevalid_i)
                    begin
                        case (ps2k_scancode_i)
                            8'hF0:      // scancode = start of break code
                            begin
                                scancode_state <= AFTER_BREAK;
                            end
                            8'hE0:      // Start of extended code
                            begin
                                scancode_state <= AFTER_EXT;
                            end
                            8'hE1:      // Start of Pause key code
                            begin
                                scancode_state <= PAUSE_1;
                            end
                            default:
                            begin
                                scancode_state <= Q_FROM_BASIC;
                                q_msb <= 0;
                            end
                        endcase
                    end
                end

                AFTER_BREAK:        // After 0xf0 (break code)
                begin
                    // receiving a valid scancode pro the PS2 port?
                    if (ps2k_scodevalid_i)
                    begin
                        scancode_state <= Q_FROM_BASIC;
                        q_msb <= 1;     // mark break
                    end
                end

                AFTER_EXT:          // After 0xe0 (extended code)
                begin
                    if (ps2k_scodevalid_i)
                    begin
                        // check for Break code?
                        if (ps2k_scancode_i == 8'hF0)
                        begin
                            // yes, remember and wait for the final code
                            scancode_state <= AFTER_EXT_BREAK;
                        end else begin
                            // output translated extended code
                            scancode_state <= Q_FROM_EXT;
                            q_msb <= 0;
                        end
                    end
                end

                AFTER_EXT_BREAK:        // After 0xe0 0xf0 (extended break code)
                begin
                    if (ps2k_scodevalid_i)
                    begin
                        scancode_state <= Q_FROM_EXT;
                        q_msb <= 1;     // mark break
                    end
                end

                Q_FROM_BASIC:
                begin
                    ps2k_keycode_o <= { q_msb, basic_keycode[6:0] };
                    if (basic_keycode[6:0] != 7'd0)
                    begin
                        ps2k_kcvalid_o <= 1;
                    end
                    scancode_state <= START_NEW_SC;
                end

                Q_FROM_EXT:
                begin
                    ps2k_keycode_o <= { q_msb, ext_keycode[6:0] };
                    if (ext_keycode[6:0] != 7'd0)
                    begin
                        ps2k_kcvalid_o <= 1;
                    end
                    scancode_state <= START_NEW_SC;
                end

                PAUSE_1:
                    if (ps2k_scodevalid_i)
                        scancode_state <= PAUSE_2;
                    
                PAUSE_2:
                    if (ps2k_scodevalid_i)
                        scancode_state <= PAUSE_3;

                PAUSE_3:
                    if (ps2k_scodevalid_i)
                        scancode_state <= PAUSE_4;

                PAUSE_4:
                    if (ps2k_scodevalid_i)
                        scancode_state <= PAUSE_5;

                PAUSE_5:
                    if (ps2k_scodevalid_i)
                        scancode_state <= PAUSE_6;

                PAUSE_6:
                    if (ps2k_scodevalid_i)
                        scancode_state <= PAUSE_7;

                PAUSE_7:
                    if (ps2k_scodevalid_i)
                    begin
                        ps2k_keycode_o <= 8'd126;       // Break keycode
                        ps2k_kcvalid_o <= 1;
                        scancode_state <= START_NEW_SC;
                    end

                default:
                begin
                    scancode_state <= START_NEW_SC;
                end
            endcase
        end
    end


endmodule
