; .CODE
; .ORG $FFF0
.SEGMENT "CODE"

VIA1_DDRB_REG = $9F02



START:
    LDX #$FF
    TXS

    lda #$02        ; CPULED1
    sta VIA1_DDRB_REG       ; VIA1 DDRB

    ; // FFF0: any vector starts
    LDA  #1
L1:
    PHA
    and  #$02
    sta $9F00
    LDA  #2
    PLA
    INC A

    PHA

    LDX  #$00
    LDA  #$00
L2:
    INC A
    BNE  L2
    INX
    BNE  L2

    PLA
    BRA  L1   ; (@PHA)
    


; .ORG $FFFA
.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
