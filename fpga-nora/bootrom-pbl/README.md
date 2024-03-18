Primary Bootloader
===================

This directory provides the sources of the Primary Bootloader (PBL).
Compiled code is stored in 512Byte BlockRAM inside of NORA FPGA. It gets there as part of verilog synthesis.
This special BlockRAM is mapped to CPU address space at $FE00 by configuring the register ROMBLOCK bit 7 = 1 (i.e. 0x80).
That is the default after a system reset, so that PBL starts automatically.

Note: Vector Pull (RESET, IRQ, NMI, ...) always happens from ROMBLOCK = 0, *unless* ROMBLOCK[7] = 1 is configured; 
then it happens from the PBL ROMBLOCK.

The PBL must be short (less than 512B) to fit in the FPGA.
It initializes NORA's SPI-Flash and reads the SBL starting at offset 256kB. 
(NORA bitstream takes the first cca 132kB, and flash erase is done in 64kB increments.)
Presently we load 256kB of secondary ROM.
