.P816

.include "common.inc"
.include "nora.inc"
.include "vera.inc"
.include "vt.inc"

.export _kbd_put_char, _kbd_put_shift, _kbd_put_ctrl, _kbd_put_alt, _kbd_put_special
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
    bmi     done

    ; Use kbd_map as a lookup table to get the translation.
    ; Each entry in the table is 4-bytes long:
    ;   1st and 2nd byte = a word: handling routine
    ;   3rd byte = ascii code, unshifted
    ;   4th byte = ascii code, shifted
    ; The table has only 128 entries, because the key-codes are really 7-bit.

    pha                 ; remember the original 8b keycode on stack
    ACCU_INDEX_16_BIT
    and     #$007f      ; mask out the 8th bit
    asl                 ; multiply by 4
    asl
    tax
    ACCU_8_BIT
    ; switch segments: DBR must be the same as PBR
    phb             ; save the current DBR
    phk             ; save the current PBR
    plb             ; restore the DBR from PBR

    pla             ; get the original 8b keycode
    jsr     (kbd_map, X)  ; get the first byte of the entry
    
    ; A has the ascii code
    sta     z:bKBD_NEXT_ASCII

    plb             ; restore the original DBR
done:
    rtl
.endproc


; Normal character from key-code to ascii
.proc _kbd_put_char
    lda     kbd_map+2, X
    rts
.endproc

.proc _kbd_put_shift
    rts
.endproc

.proc  _kbd_put_ctrl
    rts
.endproc

.proc _kbd_put_alt
    rts
.endproc

.proc _kbd_put_special
    rts
.endproc
