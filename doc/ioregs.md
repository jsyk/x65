IO Registers
=============

TBD: here we should describe centrally all the I/O registers and bits that we have!!

There are 256 Bytes of address space reserved for I/O registers, mapped from $9F00 to $9FFF
(65816: from $009F00 to $009FFF) in the CPU address space.
This 256B is generally diveded in 16-byte blocks that are assigned to individual "modules"
or "devices" in the system, roughly corresponding to individual chip-select signals.

In addition, there are two special registers outside this I/O area: RAMBLOCK and ROMBLOCK.
These are mapped in the CPU Zero page at the addresses $0000 and $0001, respectively
(65816: $000000 and $000001).


Overall I/O layout
----------------------

Note: In case of 65816 CPU, all I/O registers are visible just in the first 64k-Bank $00.
    => to read the tables below correctly, just add $00 in front of the presented addresses
    to obtain the fully-specified 24-bit physical address.

    Address(es) (CPU)               Module
    $0000 ... $0001                 NORA: RAMBLOCK and ROMBLOCK registers

    $9F00 ... $9F0F                 Simple-VIA_1
    $9F10 ... $9F1F                 empty (reserved for VIA_2)
    $9F20 ...                       VERA
          ... $9F3F                 VERA
    $9F40 ... $9F4F                 AURA
    $9F50                           NORA
          ... $9F6F                 NORA
    $9F70 ... $9F7F                 empty, reserved for NORA extensions
    $9F80 ... $9F8F                 Ethernet Wiznet W6100
    $9F9F ... 
          ... $9FFF                 empty
