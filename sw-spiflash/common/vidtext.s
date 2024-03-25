.Pc02

.include "common.inc"
.include "nora.inc"
.include "vera.inc"

.import _font8x8

.export vera_init
.export vera_load_font
.export vera_clear_screen
.export vera_printchar
.export vera_printbanner


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

.zeropage
PTR     = $10

.code

;-------------------------------------------------------------------------------
.proc vera_init
; Initialize VERA chip for the text mode 80 columns, 60 rows, 8x8 font
;  and clear the screen.
;
; Inputs: none
; Outputs: none
; Clobbers: A, X, Y

    ; sep     #SHORT_A|SHORT_I          ; 8-bit memory and accu
    ; .a8
    ; .i8

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

    rts
.endproc


.proc vera_clear_screen

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

    ldx     #0
loop_scr_clr:
    ldy     #0
loop_scr_clr_inner:
    lda   #' '           ; character index
    sta   VERA_DATA0_REG
    lda   #(COLOR_GRAY1 << 4) | (COLOR_WHITE)         ; backround and foreground color
    sta   VERA_DATA0_REG
    iny
    cpy     #128
    bne     loop_scr_clr_inner
    inx
    cpx     #64
    bne     loop_scr_clr


;     cpx   #128*64
;     bne   loop_scr_clr

    ; restore 8-bit index regs X, Y
    ; sep   #SHORT_I          ; 8-bit memory and accu
    ; .i8

    rts
.endproc


.proc vera_load_font
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

    lda     #<_font8x8
    sta     PTR
    lda     #>_font8x8
    sta     PTR+1
    ldx     #0
loop_font_cp:
    ldy     #0
loop_font_cp_inner:
    lda     (PTR),y
    sta     VERA_DATA0_REG
    iny
    cpy     #0
    bne     loop_font_cp_inner

    inc     PTR+1
    inx
    cpx     #SIZEOF_font8x8/256
    bne     loop_font_cp

    rts
.endproc

;-------------------------------------------------------------------------------
.proc vera_printchar
; Print a character given in A at the loaded screen position in VERA_ADDRESS_REG.
; Inputs:
;   A       character to print (B is ignored)
; Outputs:
;   none
; Clobers:
;   X

    ; ; switch A to 8-bit
    ; sep  #SHORT_A           ; 8-bit accu, mem
    ; .a8
    ; pha                     ; save character to print
    ; ; // setup for the VRAM address, autoincrement
    ; ; VERA.address = ci & 0xFFFF;
    ; ; VERA.address_hi = 0 | (1 << 4);
    ; stx     VERA_ADDRESS_REG       ; 16-bit store
    ; lda     #0 | (1 << 4)
    ; sta     VERA_ADDRESS_HI_REG

    ; pla                 ; restore character
    ; // print the character
    sta     VERA_DATA0_REG
    ; colot attribute
    lda     #(COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN)         ; backround and foreground color
    sta     VERA_DATA0_REG

    ; ; switch A to 16-bit
    ; rep     #SHORT_A
    ; .a16

    rts
.endproc


;-------------------------------------------------------------------------------
.proc vera_printbanner
    ; setup target address in VERA
    stz     VERA_ADDRESS_REG
    stz     VERA_ADDRESS_M_REG
    lda     #0 | (1 << 4)
    sta     VERA_ADDRESS_HI_REG

    ldx     #0
loop_printbanner:
    lda     banner,x
    beq     done_printbanner
    jsr     vera_printchar
    inx
    bra     loop_printbanner

done_printbanner:

    rts

banner:
    .asciiz "X65-SBC !"
    .asciiz "__   __  ____  _____        ___________  _____ "
    .asciiz "\ \ / / / ___||  ___|      /  ___| ___ \/  __ \ "
    .asciiz "\ V / / /___ |___ \ ______\ `--.| |_/ /| /  \/  "
    .asciiz "/   \ | ___ \    \ \______|`--. \ ___ \| |      "
    .asciiz "/ /^\ \| \_/ |/\__/ /      /\__/ / |_/ /| \__/\ "
    .asciiz "\/   \/\_____/\____/       \____/\____/  \____/ "

.endproc

; patorjk Epic
;            ______  _______        _______  ______   _______ 
; |\     /| / ____ \(  ____ \      (  ____ \(  ___ \ (  ____ \
; ( \   / )( (    \/| (    \/      | (    \/| (   ) )| (    \/
;  \ (_) / | (____  | (____  _____ | (_____ | (__/ / | |      
;   ) _ (  |  ___ \ (_____ \(_____)(_____  )|  __ (  | |      
;  / ( ) \ | (   ) )      ) )            ) || (  \ \ | |      
; ( /   \ )( (___) )/\____) )      /\____) || )___) )| (____/\
; |/     \| \_____/ \______/       \_______)|/ \___/ (_______/
                                                            

; patorjk Doom
; __   __  ____  _____        ___________  _____ 
; \ \ / / / ___||  ___|      /  ___| ___ \/  __ \
;  \ V / / /___ |___ \ ______\ `--.| |_/ /| /  \/
;  /   \ | ___ \    \ \______|`--. \ ___ \| |    
; / /^\ \| \_/ |/\__/ /      /\__/ / |_/ /| \__/\
; \/   \/\_____/\____/       \____/\____/  \____/
                                               
                                               

