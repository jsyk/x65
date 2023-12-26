
; .CODE
; .ORG $FFF0
.SEGMENT "LAST256"

START:
    LDX #$FF
    TXS
    ; // FFF0: any vector starts
    LDA  #1
L1:
    PHA
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
