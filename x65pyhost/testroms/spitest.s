
RAMBANK_MASK_REG = $9F50
SPI_CTRLSTAT_REG = $9F52
SPI_DATA_REG = $9F53


.SEGMENT "CODE"

.SEGMENT "LAST256"

START:
    LDX #$FF
    TXS

    ; set SPI CONTROL REG: address slave #1 = flash memory, minimum speed
    LDA #1
    STA SPI_CTRLSTAT_REG


    BRA START




.SEGMENT "VECTORS"
    ; # // FFFA,B = NMI
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
