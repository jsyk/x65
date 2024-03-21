
.feature c_comments

;==============================================================================
; VIA2 is implemented in NORA as simple_via, not all regs are supported!
; VIA1 has the same registers as VIA2, but different addresses - starts at $9F00
;==============================================================================
VIA1_PRB_REG    = $9F00         ; Port B register
VIA1_PRA_REG    = $9F01         ; Port A register
VIA1_DDRB_REG   = $9F02         ; Port B data direction register
VIA1_DDRA_REG   = $9F03         ; Port A data direction register
VIA1_T1_LO_REG  = $9F04         ; Timer 1, low byte
VIA1_T1_HI_REG  = $9F05         ; Timer 1, high byte
VIA1_T1L_LO_REG = $9F06         ; Timer 1 latch, low byte
VIA1_T1L_HI_REG = $9F07         ; Timer 1 latch, high byte
VIA1_T2_LO_REG  = $9F08         ; Timer 2, low byte
VIA1_T2_HI_REG  = $9F09         ; Timer 2, high byte
VIA1_SR_REG     = $9F0A         ; Shift register
VIA1_ACR_REG    = $9F0B         ; Auxiliary control register
VIA1_PCR_REG    = $9F0C         ; Peripheral control register
VIA1_IFR_REG    = $9F0D         ; Interrupt flag register
VIA1_IER_REG    = $9F0E         ; Interrupt enable register
VIA1_PRA2_REG   = $9F0F         ; Port register A w/o handshake

;==============================================================================
; VIA2 is implemented in NORA as simple_via, not all regs are supported!
;==============================================================================
VIA2_PRB_REG    = $9F10         ; Port B register
VIA2_PRA_REG    = $9F11         ; Port A register
VIA2_DDRB_REG   = $9F12         ; Port B data direction register
VIA2_DDRA_REG   = $9F13         ; Port A data direction register
VIA2_T1_LO_REG  = $9F14         ; Timer 1, low byte
VIA2_T1_HI_REG  = $9F15         ; Timer 1, high byte
VIA2_T1L_LO_REG = $9F16         ; Timer 1 latch, low byte
VIA2_T1L_HI_REG = $9F17         ; Timer 1 latch, high byte
VIA2_T2_LO_REG  = $9F18         ; Timer 2, low byte
VIA2_T2_HI_REG  = $9F19         ; Timer 2, high byte
VIA2_SR_REG     = $9F1A         ; Shift register
VIA2_ACR_REG    = $9F1B         ; Auxiliary control register
VIA2_PCR_REG    = $9F1C         ; Peripheral control register
VIA2_IFR_REG    = $9F1D         ; Interrupt flag register
VIA2_IER_REG    = $9F1E         ; Interrupt enable register
VIA2_PRA2_REG   = $9F1F         ; Port register A w/o handshake

; VIA2_PRB_REG signals
VIA2_PRB__CPULED0N = $01      ; green
VIA2_PRB__CPULED1N = $02      ; red
VIA2_PRB__DIPLED0N = $04
VIA2_PRB__DIPLED1N = $08
