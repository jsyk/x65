.P816

.include "common.inc"
.include "nora.inc"
.include "vera.inc"
.include "vt.inc"

.import _font8x8

.export vera_init
.export vt_printstr_at_a16i8far

TV_VGA = $01
LAYER0_ENABLE = $10

;// # map entries start at address 0 of VRAM, and occupy 32kB
mapbase_va = $00;

; # tile (font) starts at 32kB offset in VRAM
tilebase_va = $8000           ;// # v-addr 32768

; we just know this
SIZEOF_font8x8 = 2048

MAP_WH_32T  = 0
MAP_WH_64T  = 1
MAP_WH_128T = 2
MAP_WH_256T = 3

BPP_1  = 0
BPP_2  = 1
BPP_4  = 2
BPP_8  = 3

.code

;-------------------------------------------------------------------------------
.proc vera_init
; Initialize VERA chip for the text mode 80 columns, 60 rows, 8x8 font
;  and clear the screen.
;
; Inputs: none
; Outputs: none
; Clobbers: A, X, Y

/*  VERA Initialization 

     // # DCSEL=0, ADRSEL=0
    VERA.control = 0x00;
    // # Enable output to VGA 640x480, enable Layer0
    VERA.display.video = TV_VGA | LAYER0_ENABLE;
 
    // # DCSEL=0, ADRSEL=0
    VERA.control = 0x00;

    // characters are 8x8, visible screen 80 columns, 60 rows.
    // # Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
    VERA.layer0.config = (MAP_WH_128T << 6) | (MAP_WH_128T << 4) | BPP_1;

    // # map entries start at address 0 of VRAM, and occupy 32kB
    const uint32_t mapbase_va = 0x00;
    VERA.layer0.mapbase = mapbase_va;

    // # tile (font) starts at 32kB offset
    const uint32_t tilebase_va = 0x8000;           // # v-addr 32768

    // # TileBase (font) starts at 32kB offset. Each tile is 8x8 pixels
    VERA.layer0.tilebase = ((tilebase_va >> 11) << 2);
*/
    ; DCSEL=0, ADRSEL=0
    stz   VERA_CONTROL_REG
    ; Enable output to VGA 640x480, enable Layer0
    lda   #TV_VGA | LAYER0_ENABLE
    sta   VERA_VIDEO_REG
    ; DCSEL=0, ADRSEL=0
    stz   VERA_CONTROL_REG

    ; characters are 8x8, visible screen 80 columns, 60 rows.
    ; # Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
    lda   #MAP_WH_128T << 6 | MAP_WH_128T << 4 | BPP_1
    sta   VERA_LAYER0_CONFIG_REG

    ; map entries start at address 0 of VRAM, and occupy 32kB
    lda   #mapbase_va
    sta   VERA_LAYER0_MAPBASE_REG

    ; tile (font) starts at 32kB offset
    lda   #(tilebase_va >> 11) << 2
    sta   VERA_LAYER0_TILEBASE_REG

/*  FONT LOADING

    // configure addressing ptr at the font data (tilebase), autoincrement
    VERA.address = tilebase_va;
    VERA.address_hi = ((tilebase_va >> 16) & 1) | (1 << 4);
    // copy font data to VRAM
    for (int i = 0; i < SIZEOF_font8x8; i++)
    {
        VERA.data0 = font8x8[i];
    }
*/
    ; configure addressing ptr at the font data (tilebase), autoincrement
    lda   #<tilebase_va
    sta   VERA_ADDRESS_REG
    lda   #>tilebase_va
    sta   VERA_ADDRESS_M_REG
    lda   #((tilebase_va >> 16) & 1) | (1 << 4)
    sta   VERA_ADDRESS_HI_REG
    rep   #SHORT_I          ; 16-bit index regs X, Y
    sep   #SHORT_A          ; 8-bit memory and accu
    .i16
    .a8
    ; copy font data to VRAM
    ldx   #0
loop_font_cp:
    lda   _font8x8,x
    sta   VERA_DATA0_REG
    inx
    cpx   #SIZEOF_font8x8
    bne   loop_font_cp

/*
    // configure addressing ptr at the screen character data (map), autoincrement
    VERA.address = mapbase_va;
    VERA.address_hi = ((mapbase_va >> 16) & 1) | (1 << 4);
    // clear the virtual screen: 128 columns by 64 rows.
    for (int i = 0; i < 128*64; i++)
    {
        VERA.data0 = ' ';           // character index
        VERA.data0 = (COLOR_GRAY1 << 4) | (COLOR_WHITE);         // backround and foreground color
    }
*/
    ; configure addressing ptr at the screen character data (map), autoincrement
    lda   #<mapbase_va
    sta   VERA_ADDRESS_REG
    lda   #>mapbase_va
    sta   VERA_ADDRESS_M_REG
    lda   #((mapbase_va >> 16) & 1) | (1 << 4)
    sta   VERA_ADDRESS_HI_REG
    rep   #SHORT_I          ; 16-bit index regs X, Y
    sep   #SHORT_A          ; 8-bit memory and accu
    .i16
    .a8
    ; clear the virtual screen: 128 columns by 64 rows.
    ldx   #0
loop_scr_clr:
    lda   #' '           ; character index
    sta   VERA_DATA0_REG
    lda   #(COLOR_GRAY1 << 4) | (COLOR_WHITE)         ; backround and foreground color
    sta   VERA_DATA0_REG
    inx
    cpx   #128*64
    bne   loop_scr_clr

    ; restore 8-bit index regs X, Y
    sep   #SHORT_I          ; 8-bit memory and accu
    .i8

    rts
.endproc


;-------------------------------------------------------------------------------
.proc vt_printstr_at_a16i8far
; Print a string at a given position on the screen, without proper wrapping!
;
; Inputs:
;   X: column (0-79)
;   Y: row (0-59)
;   A: pointer to the string to print
; Outputs: none
; Clobbers: X, Y, A
    .i8
    .a16
/*
    // calculate VRAM address from x/y coordinates
    uint16_t ci = 2*x + 2*128*y;
*/
    ; calculate VRAM address from x/y coordinates
    ; uint16_t ci = 2*x + 2*128*y;
    pha         ; save ptr to string
    ; switch A to 8-bit
    sep   #SHORT_A          ; 8-bit memory and accu
    .a8
    txa
    asl   A
    ; A =  2*x
    xba     ; B = 2*x
    tya     ; A = y
    xba     ; BA = (y << 8) | (2*x)
    ; switch A, I to 16-bit
    rep   #SHORT_A|SHORT_I          ; 16-bit index regs X, Y
    .i16
    .a16
    tax         ; X16 = (y << 8) | (2*x) = ci
    ; switch A to 8-bit
    sep   #SHORT_A          ; 8-bit memory and accu
    .a8
    ; // setup for the VRAM address, autoincrement
    ; VERA.address = ci & 0xFFFF;
    ; VERA.address_hi = 0 | (1 << 4);
    stx     VERA_ADDRESS_REG       ; 16-bit store
    lda     #0 | (1 << 4)
    sta     VERA_ADDRESS_HI_REG
    
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
    sta     VERA_DATA0_REG         ; character
    lda     #(COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN)         ; backround and foreground color
    sta     VERA_DATA0_REG
    inx
    bra     loop_printstr
loop_printstr_end:

    ; restore 8-bit index regs X, Y
    sep   #SHORT_I          ; 8-bit memory and accu
    .i8
    ; restore 16-bit accu
    rep   #SHORT_A          ; 8-bit memory and accu
    .a16

    rtl         ; far return
.endproc


.i16
.a16

;-------------------------------------------------------------------------------
.proc vt_xy2cursor
; Convert X (column), Y (row) coordinates to a screen cursor.
; Inputs:
;   X: column (0-79)
;   Y: row (0-59)
; Outputs:
;   BA:u16   screen cursor: hi: row (0-59), lo: column (0-79)*2
/*
    // calculate VRAM address from x/y coordinates
    uint16_t ci = 2*x + 2*128*y;
*/
    ; switch A to 8-bit
    sep  #SHORT_A          ; 8-bit memory and accu
    .a8
    txa     ; A = x
    asl   A     ; A =  2*x
    xba     ; B = 2*x, A = undefined
    tya     ; A = y
    xba     ; BA = (y << 8) | (2*x)
    ; switch A to 16-bit
    rep  #SHORT_A          ; 16-bit index regs X, Y
    .a16
    rtl
.endproc

;-------------------------------------------------------------------------------
.proc vt_printchar_at
; Print a character given in A at the screen cursor given in X.
; Inputs:
;   A       character to print (B is ignored)
;   X:u16   screen cursor where to print: hi: row (0-59), lo: column (0-79)*2
; Outputs:
;   none
; Clobers:
;   X

    ; switch A to 8-bit
    sep  #SHORT_A           ; 8-bit accu, mem
    .a8
    pha                     ; save character to print
    ; // setup for the VRAM address, autoincrement
    ; VERA.address = ci & 0xFFFF;
    ; VERA.address_hi = 0 | (1 << 4);
    stx     VERA_ADDRESS_REG       ; 16-bit store
    lda     #0 | (1 << 4)
    sta     VERA_ADDRESS_HI_REG

    pla                 ; restore character
    ; // print the character
    sta     VERA_DATA0_REG
    ; colot attribute
    lda     #(COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN)         ; backround and foreground color
    sta     VERA_DATA0_REG

    ; switch A to 16-bit
    rep     #SHORT_A
    .a16

    rtl
.endproc


;-------------------------------------------------------------------------------
.proc vt_printchar
; Print a character given in A at the current screen cursor.
; Inputs:
;   A       character to print (B is ignored)

.endproc



