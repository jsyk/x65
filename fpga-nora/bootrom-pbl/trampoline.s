.include "nora.inc"

.Pc02
.SEGMENT "CODE"
    ;STA 1
    STA     NORA_RMBCTRL_REG
    JMP     ($FFFC)
