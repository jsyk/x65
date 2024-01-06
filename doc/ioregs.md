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


NORA Registers
------------------

Two special registers at the beginning of the CPU zero page:

    Address         Reg.name            Bits        Description
    $0000           RAMBLOCK            [7:0]       This 8-bit register specifies which 8kB-BLOCK of the 2MB SRAM
                                                    is mapped into the 8kB RAM-BLOCK FRAME visible at the CPU address $A000 to $BFFF. The contents 
                                                    of this 8b register is bit-wise ANDed with the register RAMBMASK (at $9F50) and the result 
                                                    is the SRAM RAM-block number.
                                                    (As described in memory-map, the 2MB SRAM has 256 of 8kB BLOCKs).
                                                    These RAM-Blocks are numbered in the 2MB SRAM starting in the MIDDLE and wrapping around: 
                                                        RAM-Block #0   is from SRAM 0x10_0000 to 0x10_1FFF,
                                                        RAM-Block #1   is from SRAM 0x10_2000 to 0x10_3FFF, etc.,
                                                        RAM-Block #127 is from SRAM 0x1F_E000 to 0x1F_FFFF,
                                                        RAM-Block #128 is from SRAM 0x00_0000 to 0x00_1FFF,
                                                        RAM-Block #129 is from SRAM 0x00_2000 to 0x00_2FFF, etc.,
                                                        RAM-Block #255 is from SRAM 0x0F_E000 to 0x0F_FFFF.
                                                    Note 1: in CX16 parlance this register is called "RAMBANK", but the function is (basically) the same.
                                                    Note 2: RAM-Blocks 128 to 132 are always mapped to the CPU "low-memory" addresses from $0000 to $9EFF. 
                                                    (65816: from $00_0000 to $00_9EFF => in Bank 0.)
                                                    RAM-Blocks 192 to 255 are also available as ROM-Blocks, see below.
    
    $0001           ROMBLOCK            [5:0]       This 6-bit register specifies which 16kB-BLOCK from the SRAM's 
                                                    512kB area 0x08_0000 to 0x0F_FFFF is mapped into the 16kB ROM-BLOCK FRAME
                                                    visible at the CPU address $C000 to $FFFF.
                                                    There are 32 x 16kB ROM-Blocks in SRAM:
                                                        ROM-Block #0  is from SRAM 0x08_0000 to 0x08_3FFF (= also known as the 8kB RAM-Blocks #192 and #193),
                                                        ROM-Block #1  is from SRAM 0x08_4000 to 0x08_7FFF (= also known as the 8kB RAM-Blocks #194 and #195), etc.,
                                                        ROM-Block #31 is from SRAM 0x0F_C000 to 0x0F_FFFF (= also known as the 8kB RAM-Blocks #254 and #255).
                                                    The ROMBLOCK register allows addressing up to 64 ROM-Blocks, but only the first 32 are available in the SRAM.
                                                    The ROMBLOCK=32 is special: it maps to the 512B boot-rom memory directly implemented in NORA BlockRAMs (type of FPGA resource) and pre-filled with the Primary Bootloader (PBL) program upon system power-up. The 512B is mirrored over the 16kB frame.
                                                    The ROMBLOCK=33 to 63 are not defined.

                                        [7:6]       The upper two bits of the ROMBLOCK register read 0, and writes are ignored.


NORA's main register block starts at $00_9F50 (65816 address), that is $9F50 in 6502.
The first two registers support *RAM-Block mapping* (at $A000) and *system reset* functions:

    Address         Reg.name            Bits        Description
    $9F50           RAMBMASK            [7:0]       Mask register for RAMBLOCK effective address calculation. 
                                                    The effective RAM-Block number is = RAMBLOCK & RAMBMASK.
                                                    For CX16 ROMs this register should be set to 0x7F to limit the RAMBLOCK addressing to 1MB.
                                                    Otherwise, RAM-Blocks 128-132, mapped to CPU "low-memory", get overwriten by the OS.
                                                    For software aware of X65 memory map this register could be set to 0xFF to allow full SRAM access even 
                                                    from 8-bit (6502) code.
                                                    (For 16-bit code (65816) using 24-bit native linear addressing the RAMBMASK is irrelevant.)
        
    $9F51           SYSRESET                        System reset trigger.
                                        [7] bit UNLOCK: to prevent unintended system resets, the SYSRESET must be first unlocked by writing 0x80 into the register.
                                        [6] unused
                                        [5] unused
                                        [4] bit NORARESET: writing 1 (after UNLOCKing) will trigger NORA reset - bitstream reloading.
                                        [3] bit AURARESET: writing 1 (after UNLOCKing) will trigger reset of AURA with bitstream reload. 
                                        [2] bit VERARESET: writing 1 (after UNLOCKing) will trigger reset of VERA with bitstream reload. 
                                        [1] bit ETHRESET: writing 1 (after UNLOCKing) will trigger reset of the Ethernet controller (Wiznet).
                                        [0] bit CPURESET: writing 1 (after UNLOCKing) will trigger CPU reset sequence. Note: ROMBANK or any other registers are not affected!

The next three registers control the *SPI-Master* periphery in NORA.
The SPI-Master can access NORA's UNIFIED ROM (really the SPI-Flash primarilly for NORA bitstream), and the SPI bus on UEXT port:

    Address         Reg.name            Bits        Description
    $9F52           N_SPI_CTRL
                                        [7:6] = reserved, 0
                                        TBD: IRQ???
                                        [5:3] = set the SPI speed - SCK clock frequency:
                                                000 = 100kHz
                                                001 = 400kHz
                                                010 = 1MHz
                                                011 = 8MHz
                                                100 = 24MHz
                                                other = reserved.
                   
                                        [2:0] = set the target SPI slave (1-7), or no slave (CS high) when 0.
                                                000 = no slave (all deselect)
                                                001 = UNIFIED ROM = NORA's SPI-Flash
                                                010 = UEXT SPI-Bus
                                                other = reserved.

    $9F53           N_SPI_STAT                      SPI Status
                                        [0] = Is RX FIFO empty?
                                        [1] = Is RX FIFO full?
                                        [2] = Is TX FIFO empty?
                                        [3] = Is TX FIFO full?
                                        [4] = reserved, 0
                                        [5] = reserved, 0
                                        [6] = reserved, 0
                                        [7] = Is BUSY - is TX/RX in progress?

    $9F54           N_SPI_DATA                      Reading dequeues data from the RX FIFO.
                                                    Writing enqueues to the TX FIFO.

The next three registers control the *USB_UART* periphery:

    Address         Reg.name            Bits        Description
    $9F55           USB_UART_CTRL
                                        [2:0] = Baud Rate
                                                000 = reserved
                                                001 = reserved
                                                010 = 9600 Bd
                                                011 = 57600 Bd
                                                100 = 115200 Bd
                                                101 = 230400 Bd
                                                110 = 1000000 Bd (non-standard freq)
                                                111 = 3000000 Bd (non-standard freq)
                                        [3] = Enable Parity generation/checking
                                        [4] = Parity Configuration: 0=even, 1=odd.
                                        [5] = Enable HW-FlowCtrl (RTS/CTS) - honoring the CTS signal.
                                                When the CTS input is active (low), transmission from FIFO is allowed.
                                                When the CTS input is inactive (high), transmissions are blocked.
                                        [6] = Enable IRQ activation on not(RX-FIFO-empty)
                                        [7] = Enable IRQ activation on not(TX-FIFO-full)

    $9F56           USB_UART_STAT                   USB(FTDI)-UART Status
                                        [0] = reserved, 0.
                                        [1] = Is RX FIFO full?
                                        [2] = Is TX FIFO empty?
                                        [3] = Is TX FIFO full?
                                        [4] = Framing Error Flag, latching, clear by writing 0.
                                        [5] = Parity Error Flag, latching, clear by writing 0.
                                        [6] = CTS signal Status: 1=CTS inactive (voltage=high), 0=CTS active (voltage=low).
                                        [7] = Is RX FIFO empty?

    $9F57           USB_UART_DATA       [7:0]       Reading dequeues data from the RX FIFO.
                                                    Writing enqueues to the TX FIFO.

The next three registers control the *UEXT_UART* periphery:

    Address         Reg.name            Bits        Description
    $9F58           UEXT_UART_CTRL                  Same as USB_UART_CTRL but for UEXT UART. 
                                                    RTS/CTS Hw-Flow-Control is not supported on UEXT UART,
    $9F59           UEXT_UART_STAT                  Same as USB_UART_STAT but for UEXT UART. 
    $9F5A           UEXT_UART_DATA                  Same as USB_UART_DATA but for UEXT UART. 

The next three registers control the *I2C Master* periphery:

    Address         Reg.name            Bits        Description
    $9F5B           I2C_CTRL
                                        [2:0] = I2C_Command field:
                                                000 = idle/no operation.
                                                001 = START_ADDRESS: generate START condition, send ADDRESS (passed via the DATA register),
                                                        then read the ACK bit, which gets written into the DATA register.
                                                010 = SEND_DATA_READ_ACK: send data to I2C from the DATA reg., read ACK bit and write it to the DATA reg.
                                                011 = RECV_DATA: receive data from the I2C bus into DATA reg
                                                100 = WRITE_ACK: write ACK/NACK which was previously prepared in the DATA reg.
                                                101 = STOP: generate stop condition
                                        
                                        [3] = Frequency: 0=100kHz, 1=400kHz.
                                        [6:4] = reserved, 0
                                        [7] = Enable IRQ when not(BUSY)

    $9F5C           I2C_STAT            [6:0] = reserved, 0
                                        [7] = BUSY flag: reads 1 if operation in progress, otherwise 0.

    $9F5D           I2C_DATA            [7:0]       Reads/writes the DATA register.

The next five registers control the dual-PS/2 periphery through the SMC:

    Address         Reg.name            Bits        Description
    $9F5E           PS2_CTRL                        PS2 Control register
                                        [0] = Disable scancode-to-keycode translation in HW. Default is 0 = translation enabled.
                                        [1] = Enable IRQ when kbd or mouse buffer has a byte
                                        [7:2] = reserved, 0

    $9F5F           PS2_STAT                        PS2 Status Register
                                        [5:0] = unused, 0
                                        [6] = Mouse Buffer FIFO is non-empty
                                        [7] = KBD Buffer FIFO is non-empty

    $9F60           PS2K_BUF            [7:0]       Keyboard buffer (FIFO output).
                                                    Reading gets the next keycode (scancode) received from the keyboard,
                                                    or 0x00 if the buffer was empty.
                                                    Writing will enqueue a 1-byte command for the keyboard.

    $9F61           PS2K_RSTAT          [7:0]       Reply status from keyboard (in response from a command).
                                                    Possible values:
                                                        0x00 => idle (no transmission started)
                                                        0x01 => transmission pending
                                                        0xFA => ACK received
                                                        0xFE => ERR received
                                                    Special case: Writing will enqueue a 2-byte command for the keyboard
                                                    (both bytes must be written in PS2K_RSTAT consequtevely.)


 * [SMC] provides these registers over I2C:
 *      0x07		Read from keyboard buffer
 *      0x18		Read ps2 (keyboard) status
 *      0x19	    00..FF	Send ps2 command
 *      0x1A        00..FF  Send 2-byte ps2 command
 *      0x21		Read from mouse buffer


    $9F62           PS2M_BUF            [7:0]       Mouse buffer (FIFO output).
    


The next register controls global IRQ/NMI masking:

The next registers control UEXT GPIO:


