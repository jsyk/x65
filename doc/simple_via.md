Simple-VIA
============

TBD: describe what is implemented in the simple-via and what not in comparison with the 6522

**Simplified VIA #1** (65C22)
------------------------------

Provides basic GPIO and Timer service.
(Timer not implemented so far.)


    Port B:  PRB @ 0x9F00, DDRB @ 0x9F02
        PB0 = CPUTYPE02 (0 => 65816, 1 => 6502)
        PB1 = 
        PB2 = 
        PB3..PB7 = IEEE488, unused, reads 11000.

    Port A: PRA @ 0x9F01, DDRB @ 0x9F03
        PA0 = SDA
        PA1 = SCL
        PA2 = NESLATCH
        PA3 = NESCLOCK
        PA4 = (NESDATA3) = 1
        PA5 = (NESDATA2) = 1
        PA6 = NESDATA1
        PA7 = NESDATA0

**Simplified VIA #2** (65C22)
------------------------------

    Port B: PRB @ 0x9F10, DDRB @ 0x9F12
        PB0 = out:CPULED0 (green, front), in:/SD_CD
        PB1 = out:CPULED1 (orange, front), in:SD_WP
        PB2 = DIPLED0, yellow, internal
        PB3 = DIPLED1, yellow, internal
        PB4 = unused
        PB5 = unused
        PB6 = unused
        PB7 = ERST, Wiznet ethernet reset, active low (has pull-up)

    Port A: PRA @ 0x9F11, DDRB @ 0x9F13
        PA0 = 
        PA1 = 
        PA2 = 
        PA3 = 
        PA4 = 
        PA5 = 
        PA6 = 
        PA7 = 
