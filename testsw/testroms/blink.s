; Assemble with ca65 / ld65.
;
; To start:
; ../../x65pyhost/do-cpureset.py --rombank 0
; ../../x65pyhost/do-loadbin.py blink.bin sram 0x080000
; 
; ../../x65pyhost/do-cpustep.py 10
;

; .CODE
; .ORG $FFF0
.SEGMENT "LAST256"

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
    RMB0  $03           ; 6502-only; 65816 executes as ORA [$3]
    SMB0  $03           ; 6502-only; 65816 executes as STA [$3]
    BRA  L1   ; (@PHA)


ABORT:
    PHA
    PLA
    RTI


.SEGMENT "EMUVECTORS"
    ; # // FFF0,1 = reserved
    .WORD START
    ; # // FFF2,3 = reserved
    .WORD START
    ; # // FFF4,5 = COP
    .WORD START
    ; # // FFF6,7 = reserved
    .WORD START
    ; # // FFF8,9 = ABORT
    .WORD ABORT
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
