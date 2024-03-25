.include "nora.inc"

; This code is not actively used, but is included for completeness:
; the assembled instructions are written by the sbl to create a trampoline
; that jumps to the main ROM code.

.Pc02
.SEGMENT "CODE"
    STA     NORA_RAMBMASK_REG
    JMP     ($FFFC)
