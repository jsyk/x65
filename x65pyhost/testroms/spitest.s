
RAMBANK_REG = $0
ROMBANK_REG = $1
RAMBANK_MASK_REG = $9F50
SPI_CTRLSTAT_REG = $9F52
SPI_DATA_REG = $9F53

SPI_CTRLSTAT__BUSY = (1 << 4)


LOAD_POINTER = $10
RAMBANK_WIN = $A000

.SEGMENT "CODE"

.SEGMENT "LAST256"

START:
    ; stack reset
    LDX #$FF
    TXS

    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA SPI_CTRLSTAT_REG
    ; send to the SPI Flash the 0xAB RELEASE FROM POWER DOWN
    LDA #$AB
    STA SPI_DATA_REG
    ; wait until done - test the BUSY flag in SPI_CTRLSTAT_REG
    JSR SPI_waitNonBusy
    ; de-select the SPI Flash to complete the release command in the flash
    LDA #$00
    STA SPI_CTRLSTAT_REG
    ; 
    ; MIN 3 us WAIT NECESSARY HERE!
    LDA #32
L2_wait3us:
    DEC
    BNE L2_wait3us
    
    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA SPI_CTRLSTAT_REG
    ; send to the SPI Flash the command = 0x03 READ DATA
    LDA #$03
    STA SPI_DATA_REG
    ; send the 24-bit start address inside of SPI flash: at offset 256k (262144 = 0x04_0000)
    LDA #$04
    STA SPI_DATA_REG
    LDA #0
    STA SPI_DATA_REG
    STA SPI_DATA_REG
    ; wait until the SPI is not busy, which means all was sent
    JSR SPI_waitNonBusy
    ; remove the first 4 bytes from SPI RX fifo - they were received just during the above commands
    LDA SPI_DATA_REG        ; dummy
    LDA SPI_DATA_REG        ; dummy
    LDA SPI_DATA_REG        ; dummy
    LDA SPI_DATA_REG        ; dummy


    ; make the whole 2MB RAM available through the RAMBANK
    LDA #$FF
    STA RAMBANK_MASK_REG
    ; swith RAMBANK to the first 8k of ROMBANK #0 - this is RAMBANK #192
    LDA #192
    ; LDA #1
    STA RAMBANK_REG     ; now $A000 points to SRAM 0x180000, which is also ROMBANK #0

    LDA #$00
    STA LOAD_POINTER
    LDA #$A0
    STA LOAD_POINTER+1

    JSR load_256B

    ;LDA #$A1
    ;STA LOAD_POINTER+1
    ;JSR load_256B

end:
    BRA end


; SUBROUTINE ---------------------------------------------------
; Load 256B from SPI flash and store at the (LOAD_POINTER).
; Inputs:
;   LOAD_POINTER -> points to the destination
; Destroys:
;   A, Y
load_256B:
    LDY #0
L1_load256:
    ; send any (dummy) data to the SPI to trigger an exchange
    LDA #0
    STA SPI_DATA_REG
    ; wait for SPI
    JSR SPI_waitNonBusy
    ; get the input data byte
    LDA SPI_DATA_REG
    ; store to RAM
    ; STA $400, X
    STA (LOAD_POINTER), Y
    INY
    BNE  L1_load256
    ; done
    RTS

; SUBROUTINE ---------------------------------------------------
; Load 8kB from SPI flash and store at the RAMBANK window 0xA000:
; Destroys:
;   X, A, Y
; load_8kB:
;     ; set the LOAD_POINTER with the beginning of the RAMBANK window 0xA000
;     LDA #<RAMBANK_WIN
;     STA LOAD_POINTER
;     LDA #>RAMBANK_WIN
;     STA LOAD_POINTER+1
;     ; for-loop 32x
;     LDX #(8192/256)
; L1_load_8kB:
;     ; get the next 256B from the SPI and store to LOAD_POINTER
;     JSR load_256B
;     ; increment the LOAD_POINTER by 256B
;     INC LOAD_POINTER+1
;     ; check for-loop
;     DEX
;     BNE L1_load_8kB
;     ; done
;     RTS


; SUBROUTINE ---------------------------------------------------
; Wait until SPI is done - test the BUSY flag in SPI_CTRLSTAT_REG
SPI_waitNonBusy:
    LDA SPI_CTRLSTAT_REG
    AND #SPI_CTRLSTAT__BUSY
    BNE SPI_waitNonBusy          ; loop while BUSY is not Zero
    ; done.
    RTS


.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
