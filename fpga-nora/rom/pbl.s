; ** Primary Bootloader for x65
; * Copyright (c) 2023 Jaroslav Sykora.
; * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory.
; 
; This code is stored inside of NORA FPGA BlockRAM, see the file bootrom.v, size=512Bytes,
; and mapped to the 65C02 address space at the last top CPU address space: $FE00 ... $FFFF.
; Assemble & link with ca65 + ld65.
;

; Register locations:
; RAM/ROM bank mapper:
RAMBANK_REG = $0
ROMBANK_REG = $1

; VIA1 - for LEDs
VIA1_ORB_IRB_REG = $9F00
VIA1_DDRB_REG = $9F02

; NORA registers:
RAMBANK_MASK_REG = $9F50
; NORA SPI to access the SPI-Flash memory of NORA
SPI_CTRL_REG = $9F52
SPI_STAT_REG = $9F53
SPI_DATA_REG = $9F54

; BUSY flag mask in the SPI_STAT_REG
SPI_STAT__BUSY = (1 << 7)

; Working Variables in the zero page
LOAD_POINTER = $10          ; 2B
LDPAGE_COUNTER = $12        ; 1B

; this is where the RAMBANK window starts in the CPU address space: $A000 up to +8kB
RAMBANK_WIN = $A000

.SEGMENT "CODE"

START:
    ; stack reset
    LDX #$FF
    TXS

    ; setup the RED LED for pin driving
    LDA #$02        ; CPULED1
    STA VIA1_DDRB_REG       ; VIA1 DDRB
    ; store 0 -> RED LED ON
    LDA VIA1_ORB_IRB_REG
    AND #!$02
    STA VIA1_ORB_IRB_REG

    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA SPI_CTRL_REG
    ; send to the SPI Flash the 0xAB RELEASE FROM POWER DOWN
    LDA #$AB
    STA SPI_DATA_REG
    ; wait until done - test the BUSY flag in SPI_STAT_REG
    JSR SPI_waitNonBusy
    ; de-select the SPI Flash to complete the release command in the flash
    LDA #$00
    STA SPI_CTRL_REG
    ; 
    ; MIN 3 us WAIT NECESSARY HERE!
    LDA #32
L2_wait3us:
    DEC
    BNE L2_wait3us
    
    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA SPI_CTRL_REG
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


    ; make the whole 2MB RAM available through the RAMBANK (unblock the mask)
    LDA #$FF
    STA RAMBANK_MASK_REG
    ; swith RAMBANK to the first 8k of ROMBANK #0 - this is RAMBANK #192
    LDA #192
    ; LDA #1
    STA RAMBANK_REG     ; now $A000 points to SRAM 0x180000, which is also ROMBANK #0


    ; how many 8kB pages shall we load from the SPI flash?
    LDA #32             ; TBD! make parametric!
    STA LDPAGE_COUNTER
    ; for-loop over LDPAGE_COUNTER
L1:
    ; get the next 8kB from SPI flash
    JSR load_8kB
    ; invert the RED LED
    LDA VIA1_ORB_IRB_REG
    EOR #$02
    STA VIA1_ORB_IRB_REG
    ; increment the RAMBANK
    INC RAMBANK_REG
    ; check for-loop counter
    DEC LDPAGE_COUNTER
    BNE L1
    ; done

    ; turn OFF the RED LED
    LDA VIA1_ORB_IRB_REG
    ORA $02
    STA VIA1_ORB_IRB_REG

    ; prepare the trampoline code at 0x80
    LDA #$85            ; STA
    STA $80
    LDA #$01            ;       $01    ; (ROMBANK_REG)
    STA $81
    LDA #$6C            ; JMP ()
    STA $82
    LDA #$FC
    STA $83
    LDA #$FF
    STA $84             ;       $FFFC

    ; make just the 1MB RAM available through the RAMBANK (block the mask)
    LDA #$7F                ; TBD make parametric!!
    STA RAMBANK_MASK_REG

    ; de-select the SPI Flash
    LDA #$00
    STA SPI_CTRL_REG

    ; load target ROMBANK => 0
    LDA #0
    ; jump to the trampoline
    JMP $80

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
load_8kB:
    ; set the LOAD_POINTER with the beginning of the RAMBANK window 0xA000
    LDA #<RAMBANK_WIN
    STA LOAD_POINTER
    LDA #>RAMBANK_WIN
    STA LOAD_POINTER+1
    ; for-loop 32x
    LDX #(8192/256)
L1_load_8kB:
    ; get the next 256B from the SPI and store to LOAD_POINTER
    JSR load_256B
    ; increment the LOAD_POINTER by 256B
    INC LOAD_POINTER+1
    ; check for-loop
    DEX
    BNE L1_load_8kB
    ; done
    RTS


; SUBROUTINE ---------------------------------------------------
; Wait until SPI is done - test the BUSY flag in SPI_STAT_REG
SPI_waitNonBusy:
    LDA SPI_STAT_REG
    AND #SPI_STAT__BUSY
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
