Wiznet Registers (Ethernet)
=============================

Wiznet W6100L operates in the Parallel bus mode.

    Address         Reg.name            Bits        Description
    $9F80           IDM_ARH             [7:0]       Indirect Mode High Address Register. It is most significant byte of the 16bit offset address
    $9F81           IDM_ARL             [7:0]       Indirect Mode Low Address Register. It is least significant byte of the 16bit offset address
    $9F82           IDM_BSR             [7:0]       Indirect Mode Block Select Register
    $9F83           IDM_DR              [7:0]       Indirect Mode Data Register

