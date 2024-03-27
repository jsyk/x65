.p816
.include "common.inc"
.include "vt.inc"


.import vera_init
.import vt_printstr_at_a16i8far
.import vt_putchar

; assume OF816 starts at $01_0000, i.e. the beginning of the BANK = $01
OF816_START  = $010000

; ========================================================================
.segment "RODATA"
hello_str:
    .asciiz "Hello, world!\n"

; ========================================================================
.code

.proc start
.i8
.a8
    ; emulation mode, also brings A and X/Y to 8-bit mode
    sec
    xce
    ; restart the stack
    ldx     #255
    txs
    ; go to the 16-bit mode; A and X/Y are still in 8-bit mode
    clc
    xce
    .a8
    .i8

    ; jsr     vera_init     ; initialize the VERA - already done in SBL!!

    rep     #SHORT_A
    .a16

    ; lda     #hello_str
    ; ldx     #0
    ; ldy     #0
    ; jsl     vt_printstr_at_a16i8far

    ; reset screen cursor position
    lda     #0
    sta     bVT_CURSOR_X
    sta     bVT_CURSOR_Y


    ; OF816 assumes full native mode
    rep     #SHORT_A|SHORT_I
    .a16
    .i16
    ; jump to OF816 start
    jmp     f:OF816_START

fin_loop:
    BRA     fin_loop
.endproc

; ========================================================================
.segment "LAST256"          ; $00_FF00-$00_FFFF
    jmp     f:vt_putchar          ; @ $00_FF00
    

; ========================================================================
; this is placed at the last 32 bytes of CPU BANK = $00
.segment "NATVECTORS"
    ; FFE0,1 = reserved
    .WORD 0
    ; FFE2,3 = reserved
    .WORD 0
    ; FFE4,5 = COP (16-bit mode)
    .WORD start
    ; FFE6,7 = BRK (16-bit mode)
    .WORD start
    ; FFE8,9 = ABORTB (16-bit mode)
    .WORD start
    ; FFEA,B = NMI (16-bit mode)
    .WORD start
    ; FFEC,D = reserved
    .WORD 0
    ; FFEE,F = IRQ (hw)
    .WORD start

.segment "EMUVECTORS"
    ; FFF0,1 = reserved
    .WORD 0
    ; FFF2,3 = reserved
    .WORD 0
    ; FFF4,5 = COP (816 in Emu mode only)
    .WORD start
    ; FFF6,7 = reserved
    .WORD 0
    ; FFF8,9 = ABORTB (816 in Emu mode only)
    .WORD start
    ; # // FFFA,B = NMI (8-bit mode)
    .WORD start
    ; # // FFFC,D = RES
    .WORD start
    ; # // FFFE,F = BRK, IRQ
    .WORD start
