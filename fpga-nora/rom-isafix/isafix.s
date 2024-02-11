; ** ISAFIX handler for x65
; * Copyright (c) 2023 Jaroslav Sykora.
; * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory.

; Register locations:
; RAM/ROM bank mapper:
RAMBLOCK_REG = $0
ROMBLOCK_REG = $1

; Direct-Page scratchpad registers.
; These are in fact in the IO Scratchpad range 0x9FF0 to 0x9FFF by virtue
; of moving the Direct Page register to 0x9F00.

TMP_IBYTE = $F4
TMP_ZPBYTE = $F5
TMP_ZPBYTEHI = $F6
TMP_RRBYTE = $F7
TMP_RRBYTEHI = $F8
TMP_BITNR = $F9


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
    ; Switch the Direct Page register to 0x9F00 -> this moves "zero page" (direct page) addressing to the Scratchpad 
    ;   in the io space at 0x9FF0 to 0x9FFF.
    ;   Switch A to 16-bits, XY to 16-bits
    REP     #$30        ; 
.A16
.I16
    ;   AB = 0x9F00
    LDA  #$9F00
    TCD         ; AB -> Direct Page reg.
    
    ; Read the faulting instruction by inspecting the stack.
    ;   Get the ptr from stack - this was the original return address
    LDA 8, S                ; 16-bit load of the faulting address from the stack
    TAX                     ; and put it to 16-bit X

    ; A to 8-bit; XY remains in 16-bits
    SEP     #$20
.A8

    ;   Read the instruction byte
    LDA a:0, X            ; 8-bit load
    ; and store it to our scratchpad.
    STA TMP_IBYTE

    ; Load the ZP byte, which is in fact an address into zero page, and store to scratchpad
    LDA a:1, X            ; 8-bit load
    STA TMP_ZPBYTE          ; zp byte from the code
    STZ TMP_ZPBYTEHI        ; zero
    ; Load the RR byte, which is the displacement for BBR/BBS branches, and sign-extend it to 16-bits
    LDA a:2, X
    STA TMP_RRBYTE
    STZ TMP_RRBYTEHI            ; zero-extend by default.
    BPL rrbytehi_is_zero        ; skip over if TMP_RRBYTEHI should stay 0
    LDA #$FF                    ; sign-extend
    STA TMP_RRBYTEHI
rrbytehi_is_zero:

    ; switch X,Y to 8-bit
    SEP     #$10
.I8

    ; Which bit is this testing/affecting?
    LDA TMP_IBYTE
    ROR
    ROR
    ROR
    ROR
    AND #$07                ; 0 to 7
    STA TMP_BITNR           ; store for debug only, not necessary.
    ; convert to mask
    ; LDX TMP_BITNR
    TAX
    LDA f:maskbits, X       ; -> mask lookup
    STA TMP_BITNR

    ; Is this BBR/BBS or RMB/SMB ?
    LDA TMP_IBYTE
    ;   check bit 3
    BIT #$08
    BEQ handle_rmb_smb      ; bit 3 is zero (opcodes LSD=7) -> RMB/SMB
    ; else bit 3 is one (opcodes LSD=F) -> BBR/BBS
handle_bbr_bbs:
    ; The faulting instruction was:
    ;   BBR0..BBR7 zp, rr
    ;   BBS0..BBS7 zp, rr
    BIT #$80                ; check bit 7 of IBYTE
    BEQ handle_bbr      ; ... is 0 (opcodes MSD=0 to 7) => BBR
    ; else is 1 (opcodes MSD=8 to F) => BBS
handle_bbs:
    ; The faulting instruction was:
    ;   BBS0..BBS7 zp, rr
    ; Test the bit# of the zp argument
    LDA (TMP_ZPBYTE)        ; 16-bit address, indirect - get the data byte
    BIT TMP_BITNR
    BNE bb_taken      ; BBS Branch on bit Set: if the result 1, then the branch is taken.
    BRA bb_not_taken        ; else not taken.

handle_bbr:
    ; The faulting instruction was:
    ;   BBR0..BBR7 zp, rr
    ; Test the bit# of the zp argument
    LDA (TMP_ZPBYTE)
    BIT TMP_BITNR
    BEQ bb_taken        ; BBR Branch on bit Reset: if result is 0, then the branch is taken.
    ; else fall to bb_not_taken

bb_not_taken:
    ; BBR/BBS should NOT be taken -> we must increment the return address on the stack to skip over the 3-byte instruction
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
    ; BBR/BBS should BE taken -> we must increment the return address on the stack by 3
    ; and then by the rr byte (which was sign-extended to 16-bit)
    ;   Switch A to 16-bits
    REP     #$20        ; 
.A16
    ;   load the return address, 16-bits
    LDA 8, S
    ;   increment by 3, because the BBR/BBS is 3-bytes long
    CLC
    ADC #3
    ADC TMP_RRBYTE      ; and add the RR byte from the original instruction, 16-bit access
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
    ; A has the IBYTE.
    ; Check IBYTE = RMB or SMB ?
    BIT #$80                ; check bit 7 of IBYTE
    BEQ handle_rmb          ; if IBYTE[7]=0, then it is RMB
    ; else it is SMB (Set memory bit), fall through
handle_smb:
    LDA (TMP_ZPBYTE)        ; 8-bit load from 16-bit address indirect: get the data byte at (zp)
    ORA TMP_BITNR           ; set the bit to 1
    STA (TMP_ZPBYTE)        ; write back
    BRA done_rmb_smb

handle_rmb:         ; Reset memory bit
    ; invert the bitmask
    LDA TMP_BITNR
    EOR #$FF
    STA TMP_BITNR
    ; get the data byte at (zp)
    LDA (TMP_ZPBYTE)        ; 8-bit load from 16-bit address indirect: get the data byte at (zp)
    AND TMP_BITNR           ; clear the bit to 0
    STA (TMP_ZPBYTE)        ; write back
    ; BRA done_rmb_smb      fall through

done_rmb_smb:
    ; SMB/RMB is done.
    ; Fix the return address on the stack - increment by two.
    ;   Switch A to 16-bits
    REP     #$20        ; 
.A16
    ;   load the return address, 16-bits
    LDA 8, S
    ;   increment by 2, because the RMB/SMB is 2-bytes long
    CLC
    ADC #2
    ;   store back
    STA 8, S
    ; A to 8-bit
    ;SEP     #$20
    ;.A8
    ; done, fall thrugh
    ; BRA handler_cleanup


handler_cleanup:
    ; Switch the Direct Page register back to 0x0000 as necessary in 65C02
    ;   Switch A to 16-bits
    REP     #$20        ; 
.A16
    ;   AB = 0x0000
    LDA  #$0000
    TCD         ; AB -> Direct Page reg.
    ; A to 8-bit
    SEP     #$20
.A8

    ; Restore the ROMBLOCK to the state after the Abort handler with PBL ROM mapped in,
    LDA ROMBLOCK_REG
    ;    by setting the bit 7, and bit 6,
    ORA #$C0
    ;    this maps NORA PBL to the memory space, and instructs NORA to clear it on RTI.
    STA ROMBLOCK_REG
    ; now we can go back to the abort handler in PBL to finish off.
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
