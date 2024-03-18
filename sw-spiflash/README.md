Software in NORA's SPI-Flash
=============================

This directory contains the software for NORA's SPI-Flash, which acts as a ROM for the system.
The SPI-Flash is divided in blocks of 64kB.
The first three blocks (192kB) are reserved for NORA FPGA bitstream.
That is followed by a 64kB block for Secondary Bootloader (SBL), and then the operating system
or a standalone application.
