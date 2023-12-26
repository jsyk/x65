; Trivial test: Walks through all the RAMBANK values.
; Assemble with ca65 / ld65.
;
; To start:
; ../do-cpureset.py --rombank 0
; ../do-loadbin.py banktest.bin sram 0x080000
; 
; ../do-cpustep.py 10
;

; .CODE
; .ORG $FFF0
.SEGMENT "LAST256"

START:
    ; init Stack pointer
    LDX #$FF
    TXS

    lda #$00
    sta $02
L1:
    sta $00         ; RAMBANK
    ldx $00         ; RAMBANK dummy read
    inc
    inc $02
    bra L1


; .ORG $FFFA
.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
