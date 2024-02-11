; ** ISAFIX handler for x65
; * Copyright (c) 2023 Jaroslav Sykora.
; * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory.

; Register locations:
; RAM/ROM bank mapper:
RAMBLOCK_REG = $0
ROMBLOCK_REG = $1

TMP_R2 = $E2
TMP_R3 = $E3
TMP_IBYTE = $E4
TMP_ZPBYTE = $E5
TMP_ZPBYTEHI = $E6
TMP_RRBYTE = $E7
TMP_RRBYTEHI = $E8
TMP_BITNR = $E9

; CPU=65C816
.P816
.A8
.I8

ISAFIX_ENTRY:           ; entry point for ISAFIX handler at address $07e000,
    ; This is called from PBL EMUABORT handler.
    ;
    ; Restore the ROMBLOCK to the state before the Abort handler
    LDA ROMBLOCK_REG
    ;    by clearing the bit 7,
    AND #$7F
    ;    this unmaps NORA PBL from the memory space (we will have to bring it back before returning!)
    STA ROMBLOCK_REG
    ;
    ; Read the faulting instruction by inspecting the stack.
    ;   Get the ptr from stack - this was the original return address
    LDA 8,S                 ; faulting address, lo byte
    STA TMP_R2
    LDA 9,S                ; faulting address, hi byte
    STA TMP_R3
    ;   Read the instruction byte
    LDA (TMP_R2)
    ; and store it to our scratchpad.
    STA TMP_IBYTE
    ; Increment ptr to get to the zp byte
    CLC
    LDA TMP_R2
    ADC #1
    STA TMP_R2
    LDA TMP_R3
    ADC #0
    STA TMP_R3
    ; Load the ZP byte
    LDA (TMP_R2)
    STA TMP_ZPBYTE
    STZ TMP_ZPBYTEHI
    ; Increment ptr to get to the rr byte
    CLC
    LDA TMP_R2
    ADC #1
    STA TMP_R2
    LDA TMP_R3
    ADC #0
    STA TMP_R3
    ; Load the RR byte
    LDA (TMP_R2)
    STA TMP_RRBYTE
    STZ TMP_RRBYTEHI
    BPL rrbytehi_is_zero        ; skip over if TMP_RRBYTEHI should stay 0
    LDA #$FF
    STA TMP_RRBYTEHI
rrbytehi_is_zero:

    ; Which bit is this testing/affecting?
    LDA TMP_IBYTE
    ROR
    ROR
    ROR
    ROR
    AND #$07                ; 0 to 7
    STA TMP_BITNR           
    ; convert to mask
    LDX TMP_BITNR
    LDA f:maskbits, X
    STA TMP_BITNR

    ; Is this BBR/BBS or RMB/SMB ?
    LDA TMP_IBYTE
    ;   clear out unimportant bits, we want just bit 3
    BIT #$08
    BEQ handle_rmb_smb      ; bit 3 is zero -> RMB/SMB
    ; else bit 3 is one -> BBR/BBS
handle_bbr_bbs:
    ; The faulting instruction was:
    ;   BBR0..BBR7 zp, rr
    ;   BBS0..BBS7 zp, rr
    LDA TMP_IBYTE
    BIT #$80
    BEQ handle_bbr
handle_bbs:
    ; The faulting instruction was:
    ;   BBS0..BBS7 zp, rr
    ; Test the bit# of the zp argument
    LDA (TMP_ZPBYTE)
    BIT TMP_BITNR
    BNE bb_taken      ; BBS: if the result 1, then the branch is taken.
    BRA bb_not_taken

handle_bbr:
    ; The faulting instruction was:
    ;   BBR0..BBR7 zp, rr
    ; Test the bit# of the zp argument
    LDA (TMP_ZPBYTE)
    BIT TMP_BITNR
    BEQ bb_taken        ; BBR: if result is 0, then the branch is taken.
    ; else fall to bb_not_taken

bb_not_taken:
    ; BBR should NOT be taken -> we must increment the return address on the stack to skip over the 3-byte instruction
    ;   Switch A to 16-bits
    REP     #$20        ; 
.A16
    ;   load the return address
    LDA 8, S
    ;   increment by 3, because the BBR/BBS is 3-bytes long
    CLC
    ADC #3
    ;   store back
    STA 8, S
    ; A to 8-bit
    SEP     #$20
.A8
    ; done
    BRA handler_cleanup

bb_taken:
    ; BBR should BE taken -> we must increment the return address on the stack by 3
    ; and by the rr byte (which must be sign-extended)
    ;   Switch A to 16-bits
    REP     #$20        ; 
.A16
    ;   load the return address, 16-bits
    LDA 8, S
    ;   increment by 3, because the BBR/BBS is 3-bytes long
    CLC
    ADC #3
    ADC TMP_RRBYTE      ; and add the RR byte from the original instruction
    ;   store back
    STA 8, S
    ; A to 8-bit
    SEP     #$20
.A8
    ; done
    BRA handler_cleanup




handle_rmb_smb:
    ; The faulting instruction was:
    ;   RMB0..RMB7 zp
    ;   SMB0..SMB7 zp

L1:
    BRA L1


handler_cleanup:
    ; Restore the ROMBLOCK to the state after the Abort handler
    LDA ROMBLOCK_REG
    ;    by setting the bit 7, and bit 6,
    ORA #$C0
    ;    this maps NORA PBL to the memory space, and instructs NORA to clear it on RTI.
    STA ROMBLOCK_REG
    ; now we can go back to the abort handler in PBL
    RTL



.SEGMENT "RODATA"

maskbits:
    .byte $01
    .byte $02
    .byte $04
    .byte $08
    .byte $10
    .byte $20
    .byte $40
    .byte $80
