AURA Registers
=================

AURA emulates the YM2151 FM-sound synthesis using the IKAOPM IP-core.
AURA registers are located from $9F40 to $9F4F.

    Address         Reg.name            Bits        Description
    $9F40           ADDR_REG            [7:0]       YM2151 Address Register
    $9F41           DATA_REG            [7:0]       YM2151 Data Register
