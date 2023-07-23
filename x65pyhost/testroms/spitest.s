
RAMBANK_MASK_REG = $9F50
SPI_CTRLSTAT_REG = $9F52
SPI_DATA_REG = $9F53

SPI_CTRLSTAT__BUSY = (1 << 4)


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

    LDX #0

L1:
    ; send any (dummy) data to the SPI to trigger an exchange
    LDA #0
    STA SPI_DATA_REG
    ; 
    JSR SPI_waitNonBusy
    ; get the data byte
    LDA SPI_DATA_REG

    STA $400, X
    INX
    BNE  L1

end:
    BRA end

; wait until done - test the BUSY flag in SPI_CTRLSTAT_REG
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
