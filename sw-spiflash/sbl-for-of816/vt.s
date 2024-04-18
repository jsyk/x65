.P816

.include "common.inc"
.include "nora.inc"
.include "vera.inc"
.include "vt.inc"

; .import _font8x8

; .export vera_init
.export vt_printstr_at
.export vt_putchar, vt_keyq
.export _vidmove, _vidtxtclear
.export _vt_handle_irq
.export vt_scr_cursor_disable, vt_scr_cursor_enable
.import kbd_process

; TV_VGA = $01
; LAYER0_ENABLE = $10

; ;// # map entries start at address 0 of VRAM, and occupy 32kB
; mapbase_va = $00;

; ; # tile (font) starts at 32kB offset in VRAM
; tilebase_va = $8000           ;// # v-addr 32768

; ; we just know this
; SIZEOF_font8x8 = 2048

; MAP_WH_32T  = 0
; MAP_WH_64T  = 1
; MAP_WH_128T = 2
; MAP_WH_256T = 3

; BPP_1  = 0
; BPP_2  = 1
; BPP_4  = 2
; BPP_8  = 3

.code

; ;-------------------------------------------------------------------------------
; .proc vera_init
; ; Initialize VERA chip for the text mode 80 columns, 60 rows, 8x8 font
; ;  and clear the screen.
; ;
; ; Inputs: none
; ; Outputs: none
; ; Clobbers: A, X, Y

; /*  VERA Initialization 

;      // # DCSEL=0, ADRSEL=0
;     VERA.control = 0x00;
;     // # Enable output to VGA 640x480, enable Layer0
;     VERA.display.video = TV_VGA | LAYER0_ENABLE;
 
;     // # DCSEL=0, ADRSEL=0
;     VERA.control = 0x00;

;     // characters are 8x8, visible screen 80 columns, 60 rows.
;     // # Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
;     VERA.layer0.config = (MAP_WH_128T << 6) | (MAP_WH_128T << 4) | BPP_1;

;     // # map entries start at address 0 of VRAM, and occupy 32kB
;     const uint32_t mapbase_va = 0x00;
;     VERA.layer0.mapbase = mapbase_va;

;     // # tile (font) starts at 32kB offset
;     const uint32_t tilebase_va = 0x8000;           // # v-addr 32768

;     // # TileBase (font) starts at 32kB offset. Each tile is 8x8 pixels
;     VERA.layer0.tilebase = ((tilebase_va >> 11) << 2);
; */
;     ; DCSEL=0, ADRSEL=0
;     stz   VERA_CONTROL_REG
;     ; Enable output to VGA 640x480, enable Layer0
;     lda   #TV_VGA | LAYER0_ENABLE
;     sta   VERA_VIDEO_REG
;     ; DCSEL=0, ADRSEL=0
;     stz   VERA_CONTROL_REG

;     ; characters are 8x8, visible screen 80 columns, 60 rows.
;     ; # Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
;     lda   #MAP_WH_128T << 6 | MAP_WH_128T << 4 | BPP_1
;     sta   VERA_LAYER0_CONFIG_REG

;     ; map entries start at address 0 of VRAM, and occupy 32kB
;     lda   #mapbase_va
;     sta   VERA_LAYER0_MAPBASE_REG

;     ; tile (font) starts at 32kB offset
;     lda   #(tilebase_va >> 11) << 2
;     sta   VERA_LAYER0_TILEBASE_REG

; /*  FONT LOADING

;     // configure addressing ptr at the font data (tilebase), autoincrement
;     VERA.address = tilebase_va;
;     VERA.address_hi = ((tilebase_va >> 16) & 1) | (1 << 4);
;     // copy font data to VRAM
;     for (int i = 0; i < SIZEOF_font8x8; i++)
;     {
;         VERA.data0 = font8x8[i];
;     }
; */
;     ; configure addressing ptr at the font data (tilebase), autoincrement
;     lda   #<tilebase_va
;     sta   VERA_ADDRESS_REG
;     lda   #>tilebase_va
;     sta   VERA_ADDRESS_M_REG
;     lda   #((tilebase_va >> 16) & 1) | (1 << 4)
;     sta   VERA_ADDRESS_HI_REG
;     rep   #SHORT_I          ; 16-bit index regs X, Y
;     sep   #SHORT_A          ; 8-bit memory and accu
;     .i16
;     .a8
;     ; copy font data to VRAM
;     ldx   #0
; loop_font_cp:
;     lda   _font8x8,x
;     sta   VERA_DATA0_REG
;     inx
;     cpx   #SIZEOF_font8x8
;     bne   loop_font_cp

; /*
;     // configure addressing ptr at the screen character data (map), autoincrement
;     VERA.address = mapbase_va;
;     VERA.address_hi = ((mapbase_va >> 16) & 1) | (1 << 4);
;     // clear the virtual screen: 128 columns by 64 rows.
;     for (int i = 0; i < 128*64; i++)
;     {
;         VERA.data0 = ' ';           // character index
;         VERA.data0 = (COLOR_GRAY1 << 4) | (COLOR_WHITE);         // backround and foreground color
;     }
; */
;     ; configure addressing ptr at the screen character data (map), autoincrement
;     lda   #<mapbase_va
;     sta   VERA_ADDRESS_REG
;     lda   #>mapbase_va
;     sta   VERA_ADDRESS_M_REG
;     lda   #((mapbase_va >> 16) & 1) | (1 << 4)
;     sta   VERA_ADDRESS_HI_REG
;     rep   #SHORT_I          ; 16-bit index regs X, Y
;     sep   #SHORT_A          ; 8-bit memory and accu
;     .i16
;     .a8
;     ; clear the virtual screen: 128 columns by 64 rows.
;     ldx   #0
; loop_scr_clr:
;     lda   #' '           ; character index
;     sta   VERA_DATA0_REG
;     lda   #(COLOR_GRAY1 << 4) | (COLOR_WHITE)         ; backround and foreground color
;     sta   VERA_DATA0_REG
;     inx
;     cpx   #128*64
;     bne   loop_scr_clr

;     ; restore 8-bit index regs X, Y
;     sep   #SHORT_I          ; 8-bit memory and accu
;     .i8

;     rts
; .endproc


;-------------------------------------------------------------------------------
.proc vt_printstr_at
; Print a string at a given position on the screen, without proper wrapping!
;
; Inputs:
;   X: column (0-79)
;   Y: row (0-59)
;   A: pointer to the string to print
; Outputs: none
; Clobbers: X, Y, A
    ACCU_16_BIT
    INDEX_8_BIT
/*
    // calculate VRAM address from x/y coordinates
    uint16_t ci = 2*x + 2*128*y;
*/
    pha         ; save ptr to string
    ; switch A to 8-bit
    ACCU_8_BIT

    ; Setup VERA's DATA0 for output:
    ;   ADDRSEL = 0
    lda     #0
    sta     f:VERA_CONTROL_REG

    ; calculate VRAM address from x/y coordinates
    ; uint16_t ci = 2*x + 2*128*y;
    txa
    asl   A
    ; A =  2*x
    xba     ; B = 2*x
    tya     ; A = y
    xba     ; BA = (y << 8) | (2*x)


    sta     f:VERA_ADDRESS_REG
    xba
    sta     f:VERA_ADDRESS_M_REG

    ; switch A, I to 16-bit
    ; ACCU_INDEX_16_BIT
    ; tax         ; X16 = (y << 8) | (2*x) = ci
    ; switch A to 8-bit
    ; ACCU_8_BIT
    ; // setup for the VRAM address, autoincrement
    ; VERA.address = ci & 0xFFFF;
    ; VERA.address_hi = 0 | (1 << 4);
    ; stx     VERA_ADDRESS_REG       ; 16-bit store
    lda     #0 | (1 << 4)
    sta     f:VERA_ADDRESS_HI_REG
    
    INDEX_16_BIT
    plx         ; X = ptr to string
/*
    while (*str)
    {
        char c = *str;
        VERA.data0 = c;                 // character
        VERA.data0 = (COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN);         // backround and foreground color
        // vpoke(ci, c);              // character
        // vpoke(ci+1, 0x61);           // colors
        str++;
        // x++;
    }
*/
loop_printstr:
    lda     0,x         ; char c = *str
    beq     loop_printstr_end
    sta     f:VERA_DATA0_REG         ; character
    lda     #(COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN)         ; backround and foreground color
    sta     f:VERA_DATA0_REG
    inx
    bra     loop_printstr
loop_printstr_end:

    ; restore 8-bit index regs X, Y
    ; sep   #SHORT_I          ; 8-bit memory and accu
    ; .i8
    ; restore 16-bit accu
    ; rep   #SHORT_A          ; 8-bit memory and accu
    ; .a16

    rtl         ; far return
.endproc


.i16
.a16

;-------------------------------------------------------------------------------
.proc vt_xy2cursor
; Convert X (column), Y (row) coordinates to a screen cursor.
; Assuming full-native mode (a16, i16) upon entry and exit.
; Inputs:
;   X: column (0-79)
;   Y: row (0-59)
; Outputs:
;   BA:u16   screen cursor: hi: row (0-59), lo: column (0-79)*2
    .a16
    .i16
/*
    // calculate VRAM address from x/y coordinates
    uint16_t ci = 2*x + 2*128*y;
*/
    ; switch A to 8-bit
    ACCU_8_BIT
    
    txa     ; A = x
    asl   A     ; A =  2*x
    xba     ; B = 2*x, A = undefined
    tya     ; A = y
    xba     ; BA = (y << 8) | (2*x)
    ; switch A to 16-bit
    ACCU_16_BIT

    rtl
.endproc

;-------------------------------------------------------------------------------
.proc vt_printchar_at
; Print a character given in A at the screen cursor given in X.
; Assuming full-native mode (a16, i16) upon entry and exit.
; Inputs:
;   A       character to print (B is ignored)
;   X:u16   screen cursor where to print: hi: row (0-59), lo: column (0-79)*2
; Outputs:
;   none
; Clobers:
;   X
    .a16
    .i16

    ; switch A to 8-bit, X/Y to 16-bit
    INDEX_16_BIT
    ACCU_8_BIT
    pha                     ; save character to print
    ; Setup VERA's DATA0 for output:
    ;   ADDRSEL = 0
    lda     #0
    sta     f:VERA_CONTROL_REG
    ; switch A to 16-bit
    ACCU_16_BIT
    ; // setup for the VRAM address, autoincrement
    ; VERA.address = ci & 0xFFFF;
    ; VERA.address_hi = 0 | (1 << 4);
    txa
    ACCU_8_BIT
    ; NOTE: a 16-bit store to VERA_ADDRESS_REG does not work correctly with VERA!! We must use 2x 8-bit stores!!
    sta     f:VERA_ADDRESS_REG       ; 8-bit store
    xba
    sta     f:VERA_ADDRESS_M_REG       ; 8-bit store
    lda     #0 | (1 << 4)           ; 17-th bit is 0, autoincrement
    sta     f:VERA_ADDRESS_HI_REG       ; 8-bit store

    ; switch A to 8-bit
    ACCU_8_BIT
    pla                 ; restore character
    ; // print the character
    sta     f:VERA_DATA0_REG
    ; color attribute
    lda     #(COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN)         ; backround and foreground color
    sta     f:VERA_DATA0_REG

    rtl
.endproc


;-------------------------------------------------------------------------------
.proc vt_printchar
; Print a character given in A at the current screen cursor.
; (Don't move the screen cursor!)
; Inputs:
;   A       character to print (B is ignored)
;
    ; switch A, X, Y to 8-bit
    ACCU_INDEX_8_BIT
    pha
    ; get current cursor from bVT_CURSOR_X/Y and convert to screen cursor
    ldx    z:bVT_CURSOR_X
    ldy    z:bVT_CURSOR_Y
    jsl    vt_xy2cursor
    .a16
    ; now AB contains the screen cursor; move to X (16b)
    ACCU_INDEX_16_BIT
    ; debug: save the screen cursor to wVT_CURSOR_SCR
    sta    z:wVT_CURSOR_SCR
    tax
    ; print the character at the cursor
    ACCU_8_BIT
    pla
    jsl     vt_printchar_at
    .a16
    .i16
    rtl
.endproc


;-------------------------------------------------------------------------------
.proc _vidmove
; Move bytes in the video frame buffer.
; Inputs:
;   A:u16   number of bytes to move
;   X:u16   source ptr in VERA (limited to the first 64kB)
;   Y:u16   dest ptr in VERA
;
    ACCU_INDEX_16_BIT
    ; save all to the stack
    pha
    phy
    phx
    ; switch to 8-bits
    ACCU_8_BIT
    ; Setup VERA's DATA0 for source:
    ;   ADDRSEL = 0
    lda     #0
    sta     f:VERA_CONTROL_REG
    ;   VRAM Address lo, mid, hi
    pla     ; X_lo = source_lo
    sta     f:VERA_ADDRESS_REG
    pla     ; X_hi = source_hi
    sta     f:VERA_ADDRESS_M_REG
    lda     #(1 << 4)           ; Increment=1
    sta     f:VERA_ADDRESS_HI_REG
    ; Setup VERA's DATA1 for source:
    ;   ADDRSEL = 1
    lda     #1
    sta     f:VERA_CONTROL_REG
    ;   VRAM Address lo, mid, hi
    pla     ; Y_lo = dest_lo
    sta     f:VERA_ADDRESS_REG
    pla     ; Y_hi = dest_hi
    sta     f:VERA_ADDRESS_M_REG
    lda     #(1 << 4)           ; Increment=1
    sta     f:VERA_ADDRESS_HI_REG
    ; VRAM address setup done!
    ; X/Y is in 16-bit mode.
    ; Pull the iteration count (number of bytes) in X
    plx
    ; loop X-times and copy from VERA's DATA0 (source) to DATA1 (dest)
    beq     done
cploop:
    lda     f:VERA_DATA0_REG
    sta     f:VERA_DATA1_REG
    dex
    bne     cploop

 done:
    rtl
.endproc

;-------------------------------------------------------------------------------
.proc _vidtxtclear
; Clear bytes in the video frame buffer.
; Inputs:
;   A:u16   character+attr to write
;   X:u16   dst ptr in VERA (limited to the first 64kB)
;   Y:u16   number of words to write
;
    ACCU_INDEX_16_BIT
    pha
    phx
    ACCU_8_BIT
    ; Setup VERA's DATA0 for writing:
    ;   ADDRSEL = 0
    lda     #0
    sta     f:VERA_CONTROL_REG
    ;   VRAM Address lo, mid, hi
    pla     ; X_lo = dst_lo
    sta     f:VERA_ADDRESS_REG
    pla     ; X_hi = dst__hi
    sta     f:VERA_ADDRESS_M_REG
    lda     #(1 << 4)           ; Increment=1
    sta     f:VERA_ADDRESS_HI_REG
    ;
    ACCU_16_BIT
    pla         ; A = lo:character+hi:attr
    ACCU_8_BIT
    ; loop Y-times and write the word in A
wrloop:
    sta     f:VERA_DATA0_REG        ; store character
    xba
    sta     f:VERA_DATA0_REG        ; store attr
    xba
    dey
    bne     wrloop

    rtl
.endproc


;-------------------------------------------------------------------------------
.proc _vt_handle_irq
; Check and handle VERA IRQ.
    ACCU_8_BIT
    ; read VERA IRQ status
    lda     f:VERA_IRQ_FLAGS_REG
    ; and acknowledge it
    sta     f:VERA_IRQ_FLAGS_REG
    ; Now check: was there VSYNC [0] ?
    bit     #1
    beq     done        ; 0 => no => done
    ; yes => VSYNC
handle_vsync:
    inc     z:bVT_VSYNC_NR
done:
    rtl
.endproc

;-------------------------------------------------------------------------------
.proc vt_putchar
; Print a character given in A at the current screen cursor.
; Move the screen cursor accordingly.
; Inputs:
;   A       character to print (B is ignored)
;

    ACCU_8_BIT
    pha
    jsl     vt_scr_cursor_disable
    pla

    ; rtl
    ; switch A, X, Y to 8-bit
    ACCU_INDEX_8_BIT

    ; Decode special (non-print) characters:
    ; is this CR=13 carriage return?
    cmp     #13
    bne     check_lf
    ; yes, it is CR => move cursor to the beginning of the current line (Y is kept)
    stz     z:bVT_CURSOR_X
    bra     cursor_done

check_lf:
    ; is this LF=10 line feed?
    cmp     #10
    beq     cursor_newline       ; yes => newline (including CR, this is easification)

    ; is this BS=08 backspace?
    cmp     #08
    bne     do_print_glyph
    ; yes, this is backspace
    ; move cursor LEFT
    dec     z:bVT_CURSOR_X
    ; Xpos still positive?
    bpl     cursor_done     ; positive=yes => done
    ; Xpos is negative => line up
    dec     z:bVT_CURSOR_Y
    ; Ypos still positive?
    bpl     cursor_done     ; positive=yes => done
    ; keep at the beginnign of the screen! FIXME: scroll down??
    stz     z:bVT_CURSOR_Y
    bra     cursor_done

do_print_glyph:
    ; print character in A at the current screen cursor position
    jsl     vt_printchar
    ACCU_8_BIT

cursor_right:
    ; move cursor to the next position
    inc     z:bVT_CURSOR_X
    lda     z:bVT_CURSOR_X
    cmp     #80
    bne     cursor_done

cursor_newline:
    ; reset X to the beginning of the line
    lda     #0
    sta     z:bVT_CURSOR_X
    ; move cursor down in the Y direction
    inc     z:bVT_CURSOR_Y
    lda     z:bVT_CURSOR_Y
    ; got beyond the bottom of the screen?
    cmp     #60
    bne     cursor_done     ; not yet => done.
    ; yes => the cursor goes back to the last line
    dec     z:bVT_CURSOR_Y
    ; scroll down the screen by 1 line
    ACCU_INDEX_16_BIT
    lda     #(256*59)           ; A = number of bytes: one line is 128 chars+attr = 256 bytes, and we scroll 59 lines
    ldx     #(256*1)            ; X = source: beginning of line #1
    ldy     #0                  ; Y = destination: beginning of line #0
    jsl     _vidmove
    ; clear the last line
    ACCU_INDEX_16_BIT
    lda     #(((COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN)) << 8) | ' '
    ldx     #(256*59)           ; X = the last line ptr
    ldy     #128                ; number of char+attr
    jsl     _vidtxtclear

    ;   reset Y to the beginning of the screen; FIXME we should scroll!!
    ; lda     #0
    ; sta     z:bVT_CURSOR_Y

cursor_done:
    jsl     vt_scr_cursor_enable

    INDEX_16_BIT
    ACCU_8_BIT          ; see platform-libs.inc

    rtl
.endproc

;-------------------------------------------------------------------------------
.proc _toggle_screen_cursor
; Toggles the screen cursor - blinking box - at the current screen cursor position.
; Makes all necessary calculations and video memory access.
;
    ; switch A, X, Y to 8-bit
    ACCU_INDEX_8_BIT
    ; get current cursor from bVT_CURSOR_X/Y and convert to screen cursor
    ldx    z:bVT_CURSOR_X
    ldy    z:bVT_CURSOR_Y
    jsl    vt_xy2cursor
    ; now AB contains the screen cursor; move to X (16b)
    ACCU_INDEX_16_BIT
    ; debug: save the screen cursor to wVT_CURSOR_SCR
    sta    z:wVT_CURSOR_SCR
    tax

    ; switch A to 8-bit, X/Y to 16-bit
    INDEX_16_BIT
    ACCU_8_BIT
    ; Setup VERA's DATA0 for output:
    ;   ADDRSEL = 0
    lda     #0
    sta     f:VERA_CONTROL_REG
    ; switch A to 16-bit
    ACCU_16_BIT
    ; // setup for the VRAM address, autoincrement
    ; VERA.address = ci & 0xFFFF;
    ; VERA.address_hi = 0 | (1 << 4);
    txa
    inc     A
    ACCU_8_BIT
    ; NOTE: a 16-bit store to VERA_ADDRESS_REG does not work correctly with VERA!! We must use 2x 8-bit stores!!
    sta     f:VERA_ADDRESS_REG       ; 8-bit store
    xba
    sta     f:VERA_ADDRESS_M_REG       ; 8-bit store
    lda     #0 | (0 << 4)           ; 17-th bit is 0, NO autoincrement
    sta     f:VERA_ADDRESS_HI_REG       ; 8-bit store

    ; switch A to 8-bit
    ACCU_8_BIT
    ; Now VERA's DATA0 reg points to the attribute byte of the char under cursor

    lda     f:VERA_DATA0_REG        ; attr
    ; Switch upper and lower nibble in A
    ACCU_16_BIT
    rol     A
    rol     A
    rol     A
    rol     A
    and     #$0FF0
    sta     z:wTMP
    ACCU_8_BIT
    ora     z:wTMP+1
    ; write back the attribute byte
    sta     f:VERA_DATA0_REG

    rtl
.endproc

;-------------------------------------------------------------------------------
; Screen cursor management.
; Check Keyboard buffer; return A = 0 if no key, A = key code if key pressed.
; Inputs:
;   A       If 0, then keep keyboard character in buffer, otherwise pull it.
.proc vt_keyq
    ACCU_8_BIT
    pha             ; save the flag whether to pull the key or not out of the buffer

    ; is on-screen cursor enabled?
    lda     z:bVT_CURSOR_VISIBLE
    beq     cursor_done            ; 0 => not visible -> end

    ; how long ago did we toggle on-screen cursor?
    lda     z:bVT_VSYNC_NR
    sec
    sbc     z:bVT_CURSOR_LAST_VSYNC
    ; this is not correct, but for a first try...
    and     #$E0
    beq     cursor_done        ; not long ago -> exit

    ; cursor enabled and with a timeout -> toggle
    lda     z:bVT_CURSOR_VISIBLE
    eor     #$03        ; toggle bits [0] and [1], so 1 becomes 2 and vice-versa.
    sta     z:bVT_CURSOR_VISIBLE

    ; update the time
    lda     z:bVT_VSYNC_NR
    sta     z:bVT_CURSOR_LAST_VSYNC

    ; do the heavy video buffer work...
    jsl     _toggle_screen_cursor

cursor_done:
    ; check the keyboard buffer, possibly extracting next character
    jsl     kbd_process
    ACCU_INDEX_8_BIT
    ; load the character (in A) + flags (in B), or zero if no key.
    ACCU_16_BIT
    lda    z:bKBD_NEXT_ASCII
    ; pull the key out of the buffer?
    plx             ; restore the flag whether to pull (1) the key or not (0) out of the buffer
    beq     done
    ; remove the key from the buffer
    ldx     #$0
    stx     z:bKBD_NEXT_ASCII
done:
    INDEX_16_BIT
    ACCU_8_BIT          ; see platform-libs.inc
    rtl
.endproc

;-------------------------------------------------------------------------------
.proc vt_scr_cursor_disable
; Turn OFF the screen cursor.
    ACCU_8_BIT
    ; is on-screen cursor enabled?
    lda     z:bVT_CURSOR_VISIBLE
    beq     done            ; 0 => not visible -> end

    ; it is enabled...
    ; what is the current blink period state ? is it visible or off?
    bit     #2
    beq     disable            ; => bit [1] is zero -> not visible -> just disable
    ; it is currently in the visible period; we must remove it from the screen!
    ; do the heavy video buffer work...
    jsl     _toggle_screen_cursor
    ; now it is no longer visible
disable:
    lda     #0
    sta     z:bVT_CURSOR_VISIBLE
done:
    rtl
.endproc

;-------------------------------------------------------------------------------
.proc vt_scr_cursor_enable
; Turn ON the screen cursor.
    ACCU_8_BIT
    ; is on-screen cursor enabled?
    lda     z:bVT_CURSOR_VISIBLE
    bne     done            ; 1 or 2 => already enabled -> done

    ; it is disabled...
    ; put it into the enabled + visible state
    lda     #2
    sta     z:bVT_CURSOR_VISIBLE
    
    ; update the time
    lda     z:bVT_VSYNC_NR
    sta     z:bVT_CURSOR_LAST_VSYNC

    ; do the heavy video buffer work...
    jsl     _toggle_screen_cursor

done:
    rtl
.endproc
