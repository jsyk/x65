
; To switch index regs X/Y to 8-bit mode, the following bit must be set in the P (flags) register.
SHORT_I         = $10
; Example:
;   SEP     #SHORT_I      ; switch Index to 8-bit mode
;   REP     #SHORT_I      ; switch Index to 16-bit mode

; To switch accumulator reg A and memory accesses to 8-bit mode, the following bit must be set in the P (flags) register.
SHORT_A         = $20
; Example:
;   SEP     #SHORT_A      ; switch Accu to 8-bit mode
;   REP     #SHORT_A      ; switch Accu to 16-bit mode

; 
; Switching accumulator A to 8-bit mode
.macro ACCU_8_BIT
    sep  #SHORT_A
    .a8
.endmacro

; Switching both index regs X/Y to 8-bit mode
.macro INDEX_8_BIT
    sep  #SHORT_I
    .i8
.endmacro

; Switching both index regs X/Y and accumulator A to 8-bit mode
.macro ACCU_INDEX_8_BIT
    sep  #SHORT_A|SHORT_I
    .a8
    .i8
.endmacro

; Switching accumulator A to 16-bit mode
.macro ACCU_16_BIT
    rep  #SHORT_A
    .a16
.endmacro

; Switching both index regs X/Y to 16-bit mode
.macro INDEX_16_BIT
    rep  #SHORT_I
    .i16
.endmacro

; Switching both index regs X/Y and accumulator A to 16-bit mode
.macro ACCU_INDEX_16_BIT
    rep  #SHORT_A|SHORT_I
    .a16
    .i16
.endmacro
