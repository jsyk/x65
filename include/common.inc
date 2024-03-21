
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
