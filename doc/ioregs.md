IO Registers
=============

There are 256 Bytes of address space reserved for I/O registers, mapped from $9F00 to $9FFF
(65816: from $009F00 to $009FFF) in the CPU address space.
This 256B is generally diveded in 16-byte blocks that are assigned to individual "modules"
or "devices" in the system, roughly corresponding to individual chip-select signals.

In addition, there are two special registers outside this I/O area: RAMBLOCK and ROMBLOCK.
These are mapped in the CPU Zero page at the addresses $0000 and $0001, respectively (65816: $000000 and $000001).


Overall I/O layout
----------------------

Note: In case of 65816 CPU, all I/O registers are visible just in the first 64k-Bank $00.
    => to read the tables below correctly, just add $00 in front of the presented addresses
    to obtain the 24-bit physical address.


| Address         | Module                                                |
|-----------------|-------------------------------------------------------|
| $0000 ... $0001 | [NORA](ioregs-nora.md): RAMBLOCK, ROMBLOCK registers  |
| $9F00 ... $9F0F | [Simple-VIA #1](simple_via.md)                        |
| $9F10 ... $9F1F | [Simple-VIA #2](simple_via.md)                        |
| $9F20 ... $9F3F | [VERA](ioregs-vera.md)                                |
| $9F40 ... $9F4F | [AURA](ioregs-aura.md)                                |
| $9F50 ... $9F6F | [NORA](ioregs-nora.md)                                |
| $9F70 ... $9F7F | unused, reserved for NORA                             |
| $9F80 ... $9F8F | [W6100L](ioregs-wiznet.md) ethernet controller        |
| $9F90 ... $9FEF | unused                                                |
| $9FF0 ... $9FFF | SRAM scratchpad, used by ISAFIX handler under ABORT   |
