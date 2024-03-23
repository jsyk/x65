; ** Primary Bootloader for x65
; * Copyright (c) 2023 Jaroslav Sykora.
; * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory.
; 
; This code is stored inside of NORA FPGA BlockRAM, see the file bootrom.v, size=512Bytes,
; and mapped to the 65C02 address space at the last top CPU address space: $FE00 ... $FFFF.
; Assemble & link with ca65 + ld65.
;

.include "nora.inc"
.include "via.inc"
.include "config-pbl.inc"

; Working Variables in the zero page
LOAD_POINTER = $10          ; 2B -> ptr where to store the next byte from SPI, points inside RamBlock frame
LDPAGE_COUNTER = $12        ; 1B -> int counter for the number of 8kB pages to load from SPI
PAYLOADING_BLOCK = $13      ; 1B -> the block where the second 8kB and then the rest from SPI are loaded

.SEGMENT "CODE"
.Pc02           ; CPU=65C02

START:
    ; stack reset
    LDX #$FF
    TXS

    ; setup the CPU LEDs for pin driving, other bits (DIP LEDs) for input
    LDA #(VIA2_PRB__CPULED0N | VIA2_PRB__CPULED1N)        ; CPULED
    STA VIA2_DDRB_REG       ; VIA2 DDRB
    ; Turn CPULED0 = ON, CPULED1 = ON
    LDA #$00            ; 1 => make it off
    ; LDA #CPULED1N            ; 1 => make it off
    STA VIA2_PRB_REG

/*
    ; If the NORA_ROMBLOCK_REG bit 6 is set (1), then it is a request to boot from the specified ROMBLOCK
    ; instead from the PBL ROM.
    LDA NORA_ROMBLOCK_REG
    BIT #$40
    BEQ bootwait            ; if bit 6 is zero, then boot NORMALY from the PBL ROM
    ; otherwise, boot from the specified ROMBLOCK.
    ; We use the hardware feature: when bit 6 and 7 are set in ROMBLOCK, then these bits get cleared on next RTI.
    ; automatically. We prepare stack for the RTI:
    ;    1. push the reset vector address high byte
    ;    2. push the reset vector address low byte
    ;    3. push the flags
    ; But first we must read the reset vector address from the ROMBLOCK's end.
    ; This is done by mapping the ROMBLOCK to RAMBLOCK and reading from there.
    ;
    ; First, make the whole 2MB RAM available through the RAMBANK (unblock the mask)
    LDX #$FF
    STX NORA_RAMBMASK_REG
    ; get the pure ROMBLOCK number from the NORA_ROMBLOCK_REG by clearing control bits 6 and 7
    AND #$3F                ; clear bit 6 and 7 -> pure ROMBLOCK number
    ; multiply by 2 and add 192+1 to get the RAMBLOCK number of the higher half of the ROMBLOCK
    ASL A                   ; multiply by 2
    CLC
    ADC #193                ; convert to RAMBLOCK number, go to the higher part of the ROM
    ; ... and set it:
    STA NORA_RAMBLOCK_REG
    ; read reset vector adresses as the CPU would do:
    LDA $BFFD           ; read the reset vector from the new RAMBLOCK, high byte
    PHA                     ; push it to the stack for RTI
    LDA $BFFC           ; read the reset vector from the new RAMBLOCK, low byte
    PHA                     ; push it to the stack for RTI
    PHP                 ; push flags to the stack for RTI
    RTI                 ; "return" to the reset code in the new ROMBLOCK (hardware will clear bits 6 and 7 in NORA_ROMBLOCK_REG automatically!)
*/

    ; NORMAL reset path:
    ; Spin on DIP switch 0 ?
    ; read DIPLED0: 0 => DIP ON => stop boot here; 1 => DIP OFF => normal boot (SPI)
bootwait:
    LDA VIA2_PRB_REG        ; read DIP
    AND #VIA2_PRB__DIPLED0N           ; test DIP0
    BEQ bootwait            ; inf loop here while the bit it zero.

    ; Turn CPULED0 = ON, CPULED1 = off
    LDA #VIA2_PRB__CPULED1N            ; 1 => make it off
    STA VIA2_PRB_REG

    ; Open the SPI interface to the SPI Flash:
    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA NORA_SPI_CTRL_REG
    ; send to the SPI Flash the 0xAB RELEASE FROM POWER DOWN
    LDA #$AB
    STA NORA_SPI_DATA_REG
    ; wait until done - test the BUSY flag in NORA_SPI_STAT_REG
    JSR SPI_waitNonBusy
    ; de-select the SPI Flash to complete the release command in the flash
    LDA #$00
    STA NORA_SPI_CTRL_REG
    ; 
    ; MIN 3 us WAIT NECESSARY HERE!
    LDA #32
L2_wait3us:
    DEC
    BNE L2_wait3us
    
    ; set SPI CONTROL REG: target the slave #1 = flash memory, at the normal speed (8MHz)
    LDA #$19
    STA NORA_SPI_CTRL_REG
    ; send to the SPI Flash the command = 0x03 READ DATA
    LDA #$03
    STA NORA_SPI_DATA_REG
    ; send the 24-bit start address inside of SPI flash: at offset $04 -> 256k (262144 = 0x04_0000)
    LDA #config_flash_offset_msd
    STA NORA_SPI_DATA_REG
    LDA #0
    STA NORA_SPI_DATA_REG
    STA NORA_SPI_DATA_REG
    ; wait until the SPI is not busy, which means all was sent
    JSR SPI_waitNonBusy
    ; remove the first 4 bytes from SPI RX fifo - they were received just during the above commands
    LDA NORA_SPI_DATA_REG        ; dummy
    LDA NORA_SPI_DATA_REG        ; dummy
    LDA NORA_SPI_DATA_REG        ; dummy
    LDA NORA_SPI_DATA_REG        ; dummy


    ; make the whole 2MB RAM available through the RAMBANK (unblock the mask)
    LDA #$FF
    STA NORA_RAMBMASK_REG
    ; swith RAMBANK to the first 8kb block where the SPI data will be loaded
    LDA #config_load_ramblock   ; which RAM block to use for the SPI data?
    STA NORA_RamBLOCK_AB_REG     ; ((now $A000 points to SRAM 0x180000, which is also ROMBANK #0 - not true maybe!))

    ; get the first 8kB from SPI flash
    JSR load_8kB

    ; Now inspect the loaded block at the frame $A000:
    ; The first byte must be 'X'
    LDA $A000
    CMP #'X'
stop_not_x:
    BNE stop_not_x
    ; ok

    ; Run the SBL's pre_loading_callback
    JSR  $A020

    ; Get index of block where we should load the rest of the SPI data
    LDA $A010
    STA PAYLOADING_BLOCK

    ; Get the number of additional blocks to load from the SPI
    LDA $A011
    STA LDPAGE_COUNTER

    ; how many 8kB pages shall we load from the SPI flash?
    ; LDA #config_load_count
    ; STA LDPAGE_COUNTER

    ; Configure RamBlock frame to the first 8kB block where we should load the payload
    LDA PAYLOADING_BLOCK
    STA NORA_RamBLOCK_AB_REG

    ; for-loop over LDPAGE_COUNTER
L1:
    ; get the next 8kB from SPI flash
    JSR load_8kB
    ; invert the green LED
    LDA VIA2_PRB_REG
    EOR #VIA2_PRB__CPULED0N
    STA VIA2_PRB_REG
    ; increment the RAMBANK
    INC NORA_RamBLOCK_AB_REG
    ; check for-loop counter
    DEC LDPAGE_COUNTER
    BNE L1
    ; done

    ; turn ON the green LED, turn OFF the red LED
    LDA #VIA2_PRB__CPULED1N           ; off
    ; ORA $02
    ; AND #(!CPULED0N)        ; 0 => led on
    STA VIA2_PRB_REG

    ; de-select the SPI Flash
    LDA #$00
    STA NORA_SPI_CTRL_REG

    STZ NORA_ROMBLOCK_REG        ; ROMBLOCK = 0, but the PBL still stays mapped thanks to NORA_RMBCTRL__MAP_BOOTROM


.if config_with_trampoline = 1
    ; prepare the trampoline code at 0x80:
    ; 000000r 1  8D 53 9F         STA     NORA_RMBCTRL_REG
    ; 000003r 1  6C FC FF         JMP     ($FFFC)

    LDA #$8D            ; STA
    STA $80
    LDA #$53            ;       $..53
    STA $81
    LDA #$9F
    STA $82             ;       $9F..
    LDA #$6C            ; JMP ()
    STA $83
    LDA #$FC
    STA $84
    LDA #$FF
    STA $85             ;       $FFFC

    ; make just the 1MB RAM available through the RAMBANK (block the mask)
    LDA #$7F                ; TBD make parametric!!
    STA NORA_RAMBMASK_REG

    ; load target ROMBANK => 0
    ; LDA #0
    
    ; prepare NORA_RMBCTRL_REG config. to enable MIRROR_ZP, ENABLE_ROM_CDEF, RDONLY_EF, RDONLY_CD;
    ; clear NORA_RMBCTRL__MAP_BOOTROM so that this PBL ROM is not mapped anymore.
    LDA     #NORA_RMBCTRL__MIRROR_ZP | NORA_RMBCTRL__ENABLE_ROM_CDEF | NORA_RMBCTRL__RDONLY_EF | NORA_RMBCTRL__RDONLY_CD

    ; jump to the trampoline
    JMP $80
.endif

.if config_jump_address <> 0
    ; restore the RAMBANK frame to the first 8kB block where the SPI data was loaded
    LDA #config_load_ramblock   ; first RAM block from the SPI
    STA NORA_RamBLOCK_AB_REG    
    ; so that we can...
    ;   ... jump to the specified address
    JMP config_jump_address
.endif

        ; end of the bootloader
        ; loop forever if we ever reach this!
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
    STA NORA_SPI_DATA_REG
    ; wait for SPI
    JSR SPI_waitNonBusy
    ; get the input data byte
    LDA NORA_SPI_DATA_REG
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
    LDA #<RAMBLOCK_AREA_START
    STA LOAD_POINTER
    LDA #>RAMBLOCK_AREA_START
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
; Wait until SPI is done - test the BUSY flag in NORA_SPI_STAT_REG
SPI_waitNonBusy:
    LDA NORA_SPI_STAT_REG
    AND #NORA_SPI_STAT__BUSY
    BNE SPI_waitNonBusy          ; loop while BUSY is not Zero
    ; done.
    RTS



; ABORT in EMULATION MODE (ISAFIX) --------------------------------
; CPU=65C816
.P816
EMUABORT:
    ; save regs
    PHX
    PHA
    PHY
    ; DEBUG: stop the CPU
    ;LDA  #$80
    ;STA  NORA_SYSCTRL_REG            ; unlock
    ;LDA  NORA_SYSCTRL_REG
    ;ORA  #$02
    ;STA  NORA_SYSCTRL_REG

    ; switch to Native mode
    CLC
    XCE
    ; jump to handler in CBA=07, last 8kB in the bank = this is just below ROM-Block 0
    JSL $07E030
    ; switch back to Emu mode
    SEC
    XCE
    ; restore regs
    PLY
    PLA
    PLX
    ; ROMBLOCK[6] must be 1 by now => after the RTI the PBL ROM is cleared from the the map
    ; and CPU returns to the original code.
    RTI


.SEGMENT "VECTORS"
    ; FFF0,1 = reserved
    .WORD START
    ; FFF2,3 = reserved
    .WORD START
    ; FFF4,5 = COP (816 in Emu mode only)
    .WORD START
    ; FFF6,7 = reserved
    .WORD START
    ; FFF8,9 = ABORTB (816 in Emu mode only)
    .WORD EMUABORT
    ; # // FFFA,B = NMI (8-bit mode)
    .WORD START
    ; # // FFFC,D = RES
    .WORD START
    ; # // FFFE,F = BRK, IRQ
    .WORD START
