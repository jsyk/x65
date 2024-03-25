; This file is included in sbl.s to configure the SBL.
; Configuration for the OF816 ROM mode.
;


; To which 8k block to load the rest of application (payload); 134 = SRAM $00C000
config_payload_block = 134

; how many 8k blocks of the payload (not counting this 8k SBL); 10 == 80k
config_payload_bcount = 10

; Configure NORA_RMBCTRL_REG config. to enable the following features necessary for CX16:
;   MIRROR_ZP = mirror RAMBLOCK and ROMBLOCK registers in the zero page ($00=RAMBLOCK and $01=RAMBLOCK)
;   ENABLE_ROM_CDEF = map selected ROMBLOCK at the CPU address space $C000-$FFFF
;   RDONLY_EF = make the ROMBLOCK in range $E000-$FFFF read-only 
;   RDONLY_CD = make the ROMBLOCK in range $C000-$DFFF read-only
;   Clear NORA_RMBCTRL__MAP_BOOTROM so that the PBL ROM is not mapped anymore.
config_rmbctrl = 0

; The initial ROMBLOCK_REG
config_initial_romblock = 0

; 65C816: Enable ABRT02 exception (65C816 tries to execute 65C02-only instruction) with software ISAFIX handler
.define config_abrt02_enable    1

; Don't limit RAMBLOCK addressing
config_rambmask = $FF
