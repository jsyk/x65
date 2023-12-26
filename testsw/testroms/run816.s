; Assemble with ca65 / ld65.
;
; To start:
; ../do-cpureset.py --rombank 0
; ../do-loadbin.py run816.bin sram 0x080000
; 
; ../do-cpustep.py 10
;

; CPU=65C02
; .Pc02

; CPU=65C816
.P816

.SEGMENT "LAST256"

START:
    ; init Stack pointer
    LDX #$FF
    TXS

    ; switch to native mode
    CLC         ; C=0
    XCE         ; E=0 => 16-bits!

    ; Set Data bank register (DBR) to CPU-Bank 1


    LDA     #$12
L0:
    STA     $3456
    INC
    STA     $013456

    ; switch A to 16-bit
    REP     #$20        ; 
.A16                ; tell assembler
    nop
    STA     $013458
    PHA
    LDA     #$abcd
    PLA
    
    ; switch X, Y to 16-bit
    REP     #$10
.I16
    nop                 ; CPU status signal MX is updated after the next instruction of SEP/REP
    LDX     #$5678
    STX     $5

    ; switch A to 8-bit
    SEP     #$20
.A8                 ; tell assembler
    ; switch X,Y to 8-bit
    SEP     #$10
    nop                 ; CPU status signal MX is updated after the next instruction of SEP/REP
.I8

    BRA L0



.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
