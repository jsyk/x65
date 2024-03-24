.include "common.inc"
.include "nora.inc"

.import abrt02

.Pc02

; ===========================================================================
; Header table for the SBL.
; This is read by the PBL to extract loading parameters.
; The header must be located at the beginning of the SBL (offset 0) and it is 256 bytes long.
;
.segment "HEADER"
.proc sbl_header         ; offset 0
    .asciiz "X65"       ; identifier 16 bytes = nul terminated string, must start with 'X'

    .align 16
loading_block:      ; offset 16 ($10) - Parameter for PBL:
    .byte   192         ; To which 8k block to load the rest of application (payload); 192 == ROMBLOCK 0
loading_count:      ; offset 17 ($11) - Parameter for PBL:
    .byte   32          ; how many 8k blocks of the payload (not counting this 8k SBL); 32 == 256k
    ; the rest is filled by 0.

    ; at the offset 128 ($80) we have jumping table
    .align 128
pre_loading_callback:   ; offset 128 ($80) - Callback for PBL to call before loading the rest of application.
                        ; We arrive here after the PBL has loaded this 8kB SBL and is about to load the rest of the application.
                        ; We arrive here via the JSR instruction.
    rts

    .align 4
loading_done:       ; offset 132 ($84) - Jump address from PBL after loading the whole application
                        ; We arrive here after the PBL has loaded the whole application - SBL and the payload.
                        ; We arrive here via the JMP instruction.
    jmp     start_the_rom

    .align 4
abrt02_callback:        ; offset 136 ($88) - Callback for PBL to call when illegal 6502 opcode is executed in the 65816 CPU -> Isafix.
                        ; We arrive here via the JSL instruction: this is called in the Native mode of 65816 CPU.
.P816
    jmp     f:abrt02
.Pc02
.endproc


; ===========================================================================
; Code block for ISAFIX handler
; Loaded at the address $00_A100, but runs at the address $07_E100 !!
;

; .align 256
; .segment "ISAFIX"

; .proc abrt02
; .P816
;     ; .asciiz "ABRT02"
;     ; DEBUG: stop the CPU
;     LDA  #$80
;     STA  NORA_SYSCTRL_REG            ; unlock
;     LDA  NORA_SYSCTRL_REG
;     ORA  #$02
;     STA  NORA_SYSCTRL_REG
;     ;
;     lda     NORA_RMBCTRL_REG
;     ora     #NORA_RMBCTRL__MAP_BOOTROM|NORA_RMBCTRL__AUTO_UNMAP_BOOTROM
;     sta     NORA_RMBCTRL_REG
;     ;
;     rtl
; .Pc02
; .endproc

; ===========================================================================
; Main code block
;
.align 256
.segment "CODE"

; ---------------------------------------------------------------------------
; This is called by the PBL once all app code behind the SBL has been loaded from spi-flash
; and is available in the RAM of X65.
; The app code was loaded starting at 8k-block 'loading_block', and the `loading_count * 8k` bytes were loaded.
;
.proc start_the_rom
    ; .asciiz "start_the_rom"
    ; Prepare NORA_RMBCTRL_REG config. to enable MIRROR_ZP, ENABLE_ROM_CDEF, RDONLY_EF, RDONLY_CD;
    ;   Clear NORA_RMBCTRL__MAP_BOOTROM so that the PBL ROM is not mapped anymore.
    lda     #NORA_RMBCTRL__MIRROR_ZP | NORA_RMBCTRL__ENABLE_ROM_CDEF | NORA_RMBCTRL__RDONLY_EF | NORA_RMBCTRL__RDONLY_CD
    sta    NORA_RMBCTRL_REG

    ; Set ROMBLOCK to 0
    lda     #0
    sta     NORA_ROMBLOCK_REG           ; use the address in 9F50 area
    
    ; At this point the memory map is:
    ;   $0000-$0001: RAMBLOCK, ROMBLOCK registers (due to MIRROR_ZP)
    ;   $A000-$BFFF: RAMBLOCK_FRAME pointed to the Block 191 <- here we are execting!
    ;   $C000-$FFFF: ROMBLOCK_FRAME pointed to the ROMBLOCK 0

    ; Before jumping to the CX16 ROM code via the reset vector, we must limit CX16's access to the RAMBLOCKs
    ; to values between 0 and 127, so that it doesn't overwrite its own ROM code (blocks >= 192) 
    ; and the low-ram (blocks >= 128). This is done by setting the NORA_RAMBMASK_REG register to $7F.
    ;
    ; But if we do it from here, we cut off ourselves from the current RamBlock 191, where we are executing.
    ; Therefore we use the following trampoline code which we build at the address $0080:
    ; 000000r 1  8D 52 9F         STA     NORA_RAMBMASK_REG
    ; 000003r 1  6C FC FF         JMP     ($FFFC)

    ; build trampolinee byte by byte
    lda    #$8D         ; STA
    sta    $80
    lda    #$52
    sta    $81
    lda    #$9F         ;       $9F52 = NORA_RAMBMASK_REG
    sta    $82
    lda    #$6C         ; JMP (x)
    sta    $83
    lda    #$FC
    sta    $84
    lda    #$FF
    sta    $85          ;       $FFFC = ROM reset vector
    ;done

    ; set the value for the RAMBMASK_REG in the trampoline code
    lda     #$7F

    ; Jump to the trampoline code
    jmp     $0080
.endproc

