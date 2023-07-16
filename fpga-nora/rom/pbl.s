; .CODE
; .ORG $FFF0
.SEGMENT "CODE"

START:
    LDX #$FF
    TXS

    lda #$02        ; CPULED1
    sta $9F02       ; VIA1 DDRB

    ; // FFF0: any vector starts
    LDA  #1
L1:
    PHA
    and  #$02
    sta $9F00
    LDA  #2
    PLA
    INC A
    BRA  L1   ; (@PHA)
    


; .ORG $FFFA
.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
