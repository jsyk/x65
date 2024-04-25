.P816

.include "common.inc"
.include "nora.inc"
.include "vera.inc"
.include "vt.inc"

.export _kbd_put_char, _kbd_put_shift, _kbd_switch_xlock, _kbd_put_ctrl, _kbd_put_alt, _kbd_put_special, _kbd_put_unused
.import kbd_map
.export kbd_process

.code

;-------------------------------------------------------------------------------

.proc kbd_process
    ACCU_8_BIT
    ; check if SW keyboard buffer is empty
    lda     z:bKBD_NEXT_ASCII
    ; if non-zero, a key already in the buffer -> done
    bne     done

    ; read keycode from HW register PS2K_BUF
    lda     f:NORA_PS2K_BUF_REG
    ; if zero, no key in the buffer -> done
    beq     done

    ; Acc is non-zero -> a key-code from the buffer.
    
    ; The 8th bit is used to indicate a key-up (release) event.
    ; For now, we ignore the key-up events.
    ; bmi     done

    ; Use kbd_map as a lookup table to get the translation.
    ; Each entry in the table is 4-bytes long:
    ;   1st and 2nd byte = a word: handling routine
    ;   3rd byte = ascii code, unshifted
    ;   4th byte = ascii code, shifted
    ; The table has only 128 entries, because the key-codes are really 7-bit.

    sta     z:bKBD_LAST_KEYCODE     ; remember the original 8b keycode

    ACCU_INDEX_16_BIT
    and     #$007f      ; mask out the 8th bit
    asl                 ; multiply by 4
    asl
    tax
    ; ACCU_8_BIT
    ; switch segments: DBR must be the same as PBR so that jsr (kbd_map, X) works!
    phb             ; save the current DBR
    phk             ; save the current PBR
    plb             ; restore the DBR from PBR

    jsr     (kbd_map, X)  ; get the first word of the entry, jump to the handling sub-routine
    ; The handling sub-routine must store the ascii code in z:bKBD_NEXT_ASCII, if any, or leave it zero.
    ; And return with rts.

    plb             ; restore the original DBR
done:
    rtl
.endproc


; ------------------------------------------------------------------------------
; Table Handler: Normal character from key-code to ascii
.proc _kbd_put_char
    .a16 
    .i16
    ACCU_8_BIT
    ; first we must check if this is a key-down or key-up event
    ; get the original key-code
    lda     z:bKBD_LAST_KEYCODE
    ; if the 8th bit is set, the key is released (up) -> no ascii code
    bmi     done          ; key-up => no ascii code -> return 0, exit.
    ; key-down => we continue!
    ; What is the shift-key state?
    lda     z:bKBD_FLAGS
    bit     #KBG_FLAG__SHIFT
    beq     no_shift        ; no shift-key pressed;
    ; shift-key is pressed    
    ; get the translated ascii code
    lda     kbd_map+3, X
    ; A has the ascii code
    bra     store_key

no_shift:   ; no shift-key pressed
    ; get the translated ascii code
    lda     kbd_map+2, X

store_key:
    ; A has the ascii code
    sta     z:bKBD_NEXT_ASCII

done:
    ; key-up => no ascii code => return 0
    ACCU_16_BIT
    ; lda     #$0000
    rts
.endproc

; ------------------------------------------------------------------------------
; Table Handler: Shift-key is pressed or released
.proc _kbd_put_shift
    .a16 
    .i16
    ACCU_8_BIT
    ; get the original key-code
    lda     z:bKBD_LAST_KEYCODE
    ; if the 8th bit is set, the key is released
    bpl     shift_pressed
    ; => the key is released, clear the shift flag!
    lda     z:bKBD_FLAGS
    and     #(~KBG_FLAG__SHIFT) & $ff
    sta     z:bKBD_FLAGS
    bra     done

shift_pressed:      ; => the key is pressed, set the shift flag!
    lda     z:bKBD_FLAGS
    ora     #KBG_FLAG__SHIFT
    sta     z:bKBD_FLAGS

done:
    ACCU_16_BIT
    ; return 0, indicating no ascii code from the shift operation.
    ; lda     #$0000
    rts
.endproc

; ------------------------------------------------------------------------------
; Send a command or data byte to the PS2 keyboard
; The command is sent to the PS2K_BUF register, and the ACK is waited from the PS2K_RSTAT register.
.proc _ps2_send_cmdata
    .a8
    ACCU_8_BIT
    pha
resend:
    pla
    pha
    ; send the command to the keyboard
    sta     f:NORA_PS2K_BUF_REG
    ; wait for the ACK
wait_ps2k_ack:
    lda     f:NORA_PS2K_RSTAT_REG
    cmp     #$FA            ; ACK?
    beq     done
    cmp     #$FE            ; RESEND?
    beq     resend
    bra     wait_ps2k_ack

done:
    pla
    rts
.endproc

; ------------------------------------------------------------------------------
; Table Handler: CapsLock/NumLock/ScrollLock key is pressed or released
.proc _kbd_switch_xlock
    .a16 
    .i16
    ACCU_8_BIT
    ; get the original key-code
    lda     z:bKBD_LAST_KEYCODE
    ; if the 8th bit is set, the key is released (up) -> no action!
    bmi     done          ; key-up => no action -> return 0, exit.
    ; key-down => we continue!

    ; get the LOCK-BIT flag from the table: KBG_FLAG__SCROLL, KBG_FLAG__NUML, KBG_FLAG__CAPSL
    lda     kbd_map+2, X
    ; Invert the current state of the flags
    eor     z:bKBD_FLAGS
    ; Store the new state of the flags
    sta     z:bKBD_FLAGS

    ; update keyboard LEDs:
    ; 1. send the command 0xED to the keyboard
    ; 2. the keyboard will send back the ACK 0xFA - wait for it.
    ; 3. send the data-value with new state of the LEDs to the keyboard, where 
    ;       bit 0 = ScrollLock (KBG_FLAG__SCROLL)
    ;       bit 1 = NumLock (KBG_FLAG__NUML)
    ;       bit 2 = CapsLock (KBG_FLAG__CAPSL)
    ;       bit 3 = Compose
    ;       bit 4 = Kana
    ;       bit 5 = reserved
    ;       bit 6 = reserved
    ;       bit 7 = reserved
    ; 4. the keyboard will send back the ACK 0xFA - wait for it.
    ; note: in case the keyboard sends RESEND (0xFE), we must resend the last command/data byte.
    lda     #$ED
    jsr     _ps2_send_cmdata
    lda     z:bKBD_FLAGS
    and     #KBG_FLAG__CAPSL|KBG_FLAG__NUML|KBG_FLAG__SCROLL
    jsr     _ps2_send_cmdata
    
done:
    ACCU_16_BIT
    rts
.endproc

; ------------------------------------------------------------------------------
.proc _kbd_put_ctrl
    .a16 
    .i16
    rts
.endproc

; ------------------------------------------------------------------------------
.proc _kbd_put_alt
    .a16 
    .i16
    rts
.endproc

; ------------------------------------------------------------------------------
.proc _kbd_put_special
    .a16 
    .i16
    rts
.endproc

; ------------------------------------------------------------------------------
.proc _kbd_put_unused
    .a16 
    .i16
    lda     #$00
    rts
.endproc
