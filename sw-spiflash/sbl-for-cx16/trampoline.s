.include "nora.inc"

.Pc02
.SEGMENT "CODE"
    STA     NORA_RAMBMASK_REG
    JMP     ($FFFC)
