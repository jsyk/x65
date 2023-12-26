Primary Bootloader
===================

This directory provides the sources of the Primary Bootloader (PBL).
Compiled code is stored in 512Byte BlockRAM inside of NORA FPGA. It gets there as part of verilog synthesis.
This special BlockRAM is mapped to CPU address space at $FE00 by configuring the register ROMBLOCK = 32.
That is the default after a system reset, so that PBL starts automatically.

Note: Vector Pull (RESET, IRQ, NMI, ...) always happens from ROMBLOCK = 0, *unless* ROMBLOCK = 32 is configured; 
then it happens from the ROMBLOCK=32.

The PBL must be short (less than 512B) to fit in the FPGA.
It initializes NORA's SPI-Flash and reads the SBL starting at offset 256kB. 
(NORA bitstream takes the first cca 132kB, and flash erase is done in 64kB increments.)
The SBL could be, for example, the CX16 ROM code.
