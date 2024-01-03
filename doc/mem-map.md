Memory Map
===========

The CPU address space is 64kB (16-bit) long in case of 65C02 cpu, and 16MB (24-bit) long in case of 65C816S cpu.
NORA can map the following four sub-spaces into this CPU address space:

* **SRAM: 2 MB**, normally covering most of the CPU address space.
* **I/O device space: 256 Bytes**, normally from $9F00 to $9FFF.
* **PBL (Primary Bootloader) ROM: 512 Bytes**, normally at $FE00 when the ROMBANK 32 is selected. Physically part of NORA (FPGA Block-RAM).
* **Bank switching registers - RAMBANK and ROMBANK: 2 Bytes**, normally at $0000 and $0001.


TBD: BANK and PAGE is already defined in 65816!!
Use SEGMENT or BLOCK or FRAME ?


SRAM 2MB
---------
tbd


I/O device space: 256 Bytes
------------------------------

The 256 Byte long I/O device space is mapped in CPU address space from $9F00 to $9FFF.

    Addresses (CPU) 	Description
    9F00−9F0F 	        Simple-VIA I/O controller #1. See W65C22 datasheet.
    9F10−9F1F 	        unused (reserved for second VIA)
    9F20−9F3F 	        VERA video controller
                        https://github.com/X16Community/vera-module
    9F40−9F4F 	        AURA with IKAOPM (YM2151) audio controller (FM synthesis)

            Address     Description
            9F40        YM2151-emulated ADDR_REG
            9F41        YM2151-emulated DATA_REG
            ...
            9F4C        additional GPIO -- TBD

    9F50−9F5F 	        NORA control/status registers

            Address     Description
            9F50        RAMBANK_MASK
            9F51        unused
            9F52        NORA SPI MASTER: SPI_CTRLSTAT_REG
            9F53        NORA SPI MASTER: SPI_DATA_REG
            ...         tbd

    9F60−9F7F 	        unused
    9F80-9F8F           Ethernet LAN controller (W6100)
    9F90−9FFF 	        unused


PBL (Primary Bootloader) ROM: 512 Bytes
------------------------------------------



RAM/ROM-Block switching registers - RAMBLOCK and ROMBLOCK: 2 Bytes
---------------------------------------------------------------------


