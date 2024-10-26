; This file is included in sbl.s to configure the SBL.
; Configuration for the CX16 ROM compatibility mode.
;


; To which 8k block to load the rest of application (payload); 192 == ROMBLOCK 0
config_payload_block = 192

; how many 8k blocks of the payload (not counting this 8k SBL); 32 == 256k
config_payload_bcount = 34

; Configure NORA_RMBCTRL_REG config. to enable the following features necessary for CX16:
;   MIRROR_ZP = mirror RAMBLOCK and ROMBLOCK registers in the zero page ($00=RAMBLOCK and $01=RAMBLOCK)
;   ENABLE_ROM_CDEF = map selected ROMBLOCK at the CPU address space $C000-$FFFF
;   RDONLY_EF = make the ROMBLOCK in range $E000-$FFFF read-only 
;   RDONLY_CD = make the ROMBLOCK in range $C000-$DFFF read-only
;   Clear NORA_RMBCTRL__MAP_BOOTROM so that the PBL ROM is not mapped anymore.
config_rmbctrl = NORA_RMBCTRL__MIRROR_ZP | NORA_RMBCTRL__ENABLE_ROM_CDEF | NORA_RMBCTRL__RDONLY_EF | NORA_RMBCTRL__RDONLY_CD

; The initial ROMBLOCK_REG
config_initial_romblock = 0

; 65C816: Enable ABRT02 exception (65C816 tries to execute 65C02-only instruction) with software ISAFIX handler
.define config_abrt02_enable    1

; Limit the RAMBLOCK mask to $7F to prevent the CX16 ROM from accessing RAMBLOCKs $80-$FF.
; Reason: the RAMBLOCKS >= 128 map to ROMBLOCKS and to the low memory.
config_rambmask = $7F
