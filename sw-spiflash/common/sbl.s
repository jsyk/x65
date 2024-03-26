.include "common.inc"
.include "nora.inc"
.include "vera.inc"
.include "config-sbl.inc"

.import abrt02
.import vera_init, vera_load_font, vera_clear_screen, vera_printbanner

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
    .byte   config_payload_block         ; To which 8k block to load the rest of application (payload); 192 == ROMBLOCK 0
loading_count:      ; offset 17 ($11) - Parameter for PBL:
    .byte   config_payload_bcount          ; how many 8k blocks of the payload (not counting this 8k SBL); 32 == 256k
    ; the rest is filled by 0.

    ; at the offset 128 ($80) we have jumping table
    .align 128
pre_loading_callback:   ; offset 128 ($80) - Callback for PBL to call before loading the rest of application.
                        ; We arrive here after the PBL has loaded this 8kB SBL and is about to load the rest of the application.
                        ; We arrive here via the JSR instruction.
    jmp     pre_loading

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

    ; Before continuing, we delay a bit to let the screen come up so the user could see the banner.
    ; We do this by waiting for approx 2 second.
    ; We use the VERA_IRQ_LINE_REG register to count the VERA LINEs. The VERA IRQs are generated every 16.67ms (60Hz).
    ldx     #120            ; 120 frames = 2 seconds
    jsr     delay

    ; Configure the RMCTRL register (controls the RAMBLOCKs and the ROMBLOCKs in the NORA memory map).
    lda     #config_rmbctrl
    sta    NORA_RMBCTRL_REG

    ; Set ROMBLOCK to initial configured value
    lda     #config_initial_romblock
    sta     NORA_ROMBLOCK_REG           ; use the address in 9F50 area

.if config_abrt02_enable
    ; Enable ABRT02 in the emulation mode - detection of wrong opcodes,
    ; by setting the bit [6] ABRT02 in the NORA_SYSCTRL_REG register.
    ; But first we must unlock the register by writing $80 to it.
    lda     #$80
    sta     NORA_SYSCTRL_REG            ; unlock
    ; re-read
    lda     NORA_SYSCTRL_REG
    ora     #NORA_SYSCTRL__ABRT02
    sta     NORA_SYSCTRL_REG        ; enable ABRT02 feature
.endif

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
    lda     #config_rambmask

    ; Jump to the trampoline code
    jmp     $0080
.endproc


; ---------------------------------------------------------------------------
; This is called by the PBL before loading the rest of the application.
.proc pre_loading
    jsr     vera_init
    jsr     vera_clear_screen
    jsr     vera_load_font
    jsr     vera_printbanner
    rts
.endproc

; ---------------------------------------------------------------------------
.proc delay
; Input: X = number of frames to wait. One frame is 16.67ms (at 60Hz)
; Output: none
; Clobbers: A, X
wait_1_frame:
    lda     VERA_IRQ_LINE_REG
    clc
    sbc     #1
waiting:
    cmp     VERA_IRQ_LINE_REG
    bne     waiting
    dex
    bne     wait_1_frame
    ; done
    rts
.endproc
