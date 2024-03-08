; Assemble with ca65 / ld65.
;
; To start:
; ../../x65pyhost/do-cpureset.py --rombank 0
; ../../x65pyhost/do-loadbin.py getregs.bin sram 0x080000
; 
; ../../x65pyhost/do-cpustep.py 10
;

; .CODE
; .ORG $FFF0
.SEGMENT "LAST256"
.PC02

START:
    PHP             ; we get PC, SP, Flags
    PLP             ; 
    STA 2           ; block writes; We get A, and on 65816 we get B depending on flag M, and we get DH/DL (DPR) on address bus
    STX $4440       ; block writes; We get X, and on 65816 we get XH depending on flag X, we get DBR from CPU Bank Address.
    STY 6           ; block writes; We get Y, and on 65816 we get YH depending on flag X
    ;BRA START       ; jump back to the back to leave CPU registers in the original state

    NOP
    NOP

.P816
    CLC
    XCE
    LDA  #$12
    PHA
    PLB         ; DBR := $12

    NOP
    NOP

    PHP             ; and we get S
    PLP             ; 
    STA 2           ; +block_wr; 816: we get B depending on flag M, and we get DH/DL from CA
    STX $4440           ; +block_wr; 816: we get XH depending on flag X
    STY 6           ; +block_wr; 816: we get YH depending on flag X

    NOP
    NOP

    ; switch A to 16-bit
    REP     #$20        ; 
.A16                ; tell assembler
    NOP

    PHP             ; and we get S
    PLP             ; 
    STA 2           ; +block_wr; 816: we get B depending on flag M, and we get DH/DL from CA
    STX $4440           ; +block_wr; 816: we get XH depending on flag X
    STY 6           ; +block_wr; 816: we get YH depending on flag X

    NOP
    NOP

    ; switch X, Y to 16-bit
    REP     #$10
.I16
    nop                 ; CPU status signal MX is updated after the next instruction of SEP/REP

    PHP             ; and we get S
    PLP             ; 
    STA 2           ; +block_wr; 816: we get B depending on flag M, and we get DH/DL from CA
    STX $4440           ; +block_wr; 816: we get XH depending on flag X
    STY 6           ; +block_wr; 816: we get YH depending on flag X

    ; switch A to 8-bit
    SEP     #$20
.A8                 ; tell assembler
    ; switch X,Y to 8-bit
    SEP     #$10
    nop                 ; CPU status signal MX is updated after the next instruction of SEP/REP
.I8

    BRA START

.PC02

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
