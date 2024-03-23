; Configuration for the Primary Bootloader (PBL).
; The Primary Bootloader is responsible for loading the Secondary Bootloader (or OS) from the SPI flash.
; The Primary Bootloader is located directly in the FPGA in a the special 512B boot-rom.

; Most-Significant Digit (MSD) of the offset in the flash memory where 
; the Secondary Bootloader is located.
; Flash address is a 24-bit value, and the MSD is the most significant 8 bits.
; The lower 16 bits are set to 0x0000.
config_flash_offset_msd     = $04           ; 0x040000 = 256k

; The RAM-block Number where the Secondary Bootloader will be stored.
; config_load_ramblock        = 192           ; RAMBLOCK 192 (080000) ==> ROMBLOCK 0
config_load_ramblock        = 191           ; RAMBLOCK 191 (07E000) ==> just below the ROMBLOCK 0

; How many 8kB pages shall we load from the SPI flash?
config_load_count           = 32            ; 32 * 8kB = 256kB

; Shall we use the trampoline mechanism?
; This is necessary if the Secondary Bootloader is located directly in the ROMBLOCK 0.
; config_with_trampoline      = 1             ; 1 = yes, 0 = no
config_with_trampoline      = 0             ; 1 = yes, 0 = no

; The address where we should jump to after the Secondary Bootloader has been loaded.
; This is used just in case the trampoline mechanism is NOT enabled.
; This should correspond to the loaded RAMBLOCK and the start address of the Secondary Bootloader.
; config_jump_address         = $0000         ; not used
config_jump_address         = $A028         ; entry address for loading_done

