.p816
.include "common.inc"
; .autoimport	on
.import vera_init
.import vt_printstr_at_a16i8far

; ========================================================================
.segment "RODATA"
hello_str:
    .asciiz "Hello, world!\n"

; ========================================================================
.segment "LAST256"

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

    jsr     vera_init

    rep     #SHORT_A
    .a16

    lda     #hello_str
    ldx     #0
    ldy     #0
    jsl     vt_printstr_at_a16i8far

fin_loop:
    BRA     fin_loop
.endproc


; ========================================================================
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
