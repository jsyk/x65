
RAMBANK_MASK_REG = $9F50
SPI_CTRLSTAT_REG = $9F52
SPI_DATA_REG = $9F53


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
    ; de-select the SPI Flash to complete the release command
    LDA #$00
    STA SPI_CTRLSTAT_REG
    ; 
    ; MIN 3 us WAIT NECESSARY HERE!

    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00
    LDA #$00


    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA SPI_CTRLSTAT_REG
    ; send to the SPI Flash the 0x03 READ DATA
    LDA #$03
    STA SPI_DATA_REG
    ; send the 24-bit start address in SPI flash: at offset 0
    LDA #0
    STA SPI_DATA_REG
    STA SPI_DATA_REG
    STA SPI_DATA_REG
    ; remove the first 4 bytes from SPI RX fifo - they were received just during the above commands
    LDA SPI_DATA_REG        ; dummy
    LDA SPI_DATA_REG        ; dummy
    LDA SPI_DATA_REG        ; dummy
    LDA SPI_DATA_REG        ; dummy

L1:
    ; send any (dummy) data to the SPI to trigget an exchange
    LDA #0
    STA SPI_DATA_REG
    ; 
    ; get the data byte
    LDA SPI_DATA_REG

    BRA L1




.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
