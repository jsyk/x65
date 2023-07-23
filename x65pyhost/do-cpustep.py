#!/usr/bin/python3
import x65ftdi
from icd import *
import argparse
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style

colorama_init()

apa = argparse.ArgumentParser(usage="%(prog)s [OPTION] [count]",
    description="Step the CPU."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0"
)

apa.add_argument('count', default=32)

args = apa.parse_args()

step_count = int(args.count, 0)

icd = ICD(x65ftdi.X65Ftdi())

# CPU Status flags
TRACE_FLAG_RWN =		1
TRACE_FLAG_VECTPULL =	8
TRACE_FLAG_MLOCK =		16
TRACE_FLAG_SYNC =		32
# CPU Control flags
TRACE_FLAG_RESETN =     8
TRACE_FLAG_IRQN =       4
TRACE_FLAG_NMIN =       2
TRACE_FLAG_ABORTN =     1

w65c02_dismap = [
    "BRK #.1", "ORA (.1,X)", "?", "?", "TSB .1", "ORA .1", "ASL .1", "RMB0 .1", "PHP", "ORA #.1", "ASL A", "?", "TSB A", "ORA .2", "ASL .2", "BBR0 :1",
    "BPL :1", "ORA (.1),Y", "ORA (.1)", "?", "TRB .1", "ORA .1,X", "ASL .1,X", "RMB1 .1", "CLC", "ORA .2,Y", "INC A", "?", "TRB .2", "ORA .2,x", "ASL .2,x", "BBR1 :1",
    "JSR .2", "AND (.1,X)", "?", "?", "BIT .1", "AND .1", "ROL .1", "RMB2 .1", "PLP", "AND #.1", "ROL A", "?", "BIT .2", "AND .2", "ROL .2", "BBR2 :1",
    "BMI :1", "AND (.1),Y", "AND (.1)", "?", "BIT .1,X", "AND .1,X", "ROL .1,X", "RMB3 .1", "SEC", "AND .2,Y", "DEC A", "?", "BIT .2,X", "AND .2,X", "ROL .2,X", "BBR3 :1",
    "RTI", "EOR (.1,X)", "?", "?", "?", "EOR .1", "LSR .1", "RMB4 .1", "PHA", "EOR #.1", "LSR A", "?", "JMP .2", "EOR .2", "LSR .2", "BBR4 :1",
    "BVC :1", "EOR (.1),Y", "EOR (.1)", "?", "?", "EOR .1,X", "LSR .1,X", "RMB5 .1", "CLI", "EOR .2,Y", "PHY", "?", "?", "EOR .2,X", "LSR .2,X", "BBR5 :1",
    "RTS", "ADC (.1,X)", "?", "?", "STZ .1", "ADC .1", "ROR .1", "RMB6 .1", "PLA", "ADC #.1", "ROR A", "?", "JMP (.2)", "ADC .2", "ROR .2", "BBR6 :1",
    "BVS", "ADC (.1),Y", "ADC (.1)", "?", "STZ .1,X", "ADC .1,X", "ROR .1,X", "RMB7 .1", "SEI", "ADC .2,Y", "PLY", "?", "JMP (.2,X)", "ADC .2,X", "ROR .2,X", "BBR7 :1",
    "BRA :1", "STA (.1,X)", "?", "?", "STY .1", "STA .1", "STX .1", "SMB0 .1", "DEY", "BIT #.1", "TXA", "?", "STY .2", "STA .2", "STX .2", "BBS0 :1",
    "BCC :1", "STA (.1),Y", "STA (.1)", "?", "STY .1,X", "STA .1,X", "STX .1,Y", "SMB1 .1", "TYA", "STA .2,Y", "TXS", "?", "STZ .2", "STA .2,X", "STZ .2,X", "BBS1 :1",
    "LDY #.1", "LDA (.1,X)", "LDX #.1", "?", "LDY .1", "LDA .1", "LDX .1", "SMB2 .1", "TAY", "LDA #.1", "TAX", "?", "LDY A", "LDA .2", "LDX .2", "BBS2 :1",
    "BCS :1", "LDA (.1,Y)", "LDA (.1)", "?", "LDY .1,X", "LDA .1,X", "LDX .1,Y", "SMB3 .1", "CLV", "LDA .2,Y", "TSX", "?", "LDY .2,X", "LDA .2,X", "LDX .2,Y", "BBS3 :1",
    "CPY #.1", "CMP (.1,X)", "?", "?", "CPY .1", "CMP .1", "DEC .1", "SMB4 .1", "INY", "CMP #.1", "DEX", "WAI", "CPY .2", "CMP .2", "DEC .2", "BBS4 :1",
    "BNE :1", "CMP (.1),Y", "CMP (.1)", "?", "?", "CMP .1,X", "DEC .1,X", "SMB5 .1", "CLD", "CMP .2,Y", "PHX", "STP", "?","CMP .2,X", "DEC .2,X", "BBS5 :1",
    "CPX #.1", "SBC (.1,X)", "?", "?", "CPX .1", "SBC .1", "INC .1", "SMB6 .1", "INX", "SBC #.1", "NOP", "?", "CPX .2", "SBC .2", "INC .2", "BBS6 :1", 
    "BEQ :1", "SBC (.1),Y", "SBC (.1)", "?", "?", "SBC .1,X", "INC .1,X", "SMB7 .1", "SED", "SBC .2,Y", "PLX", "?", "?", "SBC .2,X", "INC .2,X", "BBS7 :1"
]


def read_byte_as_cpu(banks, CA):
    rambank = banks[0]
    rombank = banks[1]
    if 0 <= CA < 2:
        # bank regs
        rdata = icd.bankregs_read(CA, 1)
    elif CA < 0x9F00:
        # CPU low memory starts at sram fix 0x170000
        rdata = icd.sram_blockread(CA + 0x170000, 1)
    elif 0xA000 <= CA < 0xC000:
        # CPU RAM Bank starts at sram fix 0x000
        rdata = icd.sram_blockread((CA - 0xA000) + rambank*ICD.PAGESIZE, 1)
    elif 0xC000 <= CA:
        # CPU ROM bank starts at sram fix 0x180000
        rdata = icd.sram_blockread((CA - 0xC000) + 0x180000 + rombank*2*ICD.PAGESIZE, 1)
    return rdata[0]


def read_print_trace(banks):
    tbuflen = 5
    is_valid, is_ovf, tbuf = icd.cpu_read_trace(tbuflen)
    CA = tbuf[4] * 256 + tbuf[3]
    CD = tbuf[2]
    disinst = w65c02_dismap[tbuf[2]] if tbuf[0] & TRACE_FLAG_SYNC else ""

    # replace byte value
    if disinst.find('.1') >= 0:
        byteval = read_byte_as_cpu(banks, CA+1)
        disinst = disinst.replace('.1', '${:x}'.format(byteval))
    
    # replace byte value displacement
    if disinst.find(':1') >= 0:
        byteval = read_byte_as_cpu(banks, CA+1)
        # convert to signed: negative?
        if byteval > 127:
            byteval = byteval - 256
        disinst = disinst.replace(':1', '${:x}'.format(CA+2+byteval))

    # replace word value
    if disinst.find('.2') >= 0:
        wordval = read_byte_as_cpu(banks, CA+1) + read_byte_as_cpu(banks, CA+2)*256
        disinst = disinst.replace('.2', '${:x}'.format(wordval))

    is_sync = (tbuf[0] & TRACE_FLAG_SYNC)
    is_io = (CA >= 0x9F00 and CA <= 0x9FFF)
    is_write = not(tbuf[0] & TRACE_FLAG_RWN)

    print("TraceBuf: V:{} O:{}  CA:{}{:4x}{}  CD:{}{:2x}{}  ctr:{:2x}:{}{}{}{}  sta:{:2x}:{}{}{}{}     {}{}{}".format(
            ('*' if is_valid else '-'),
            ('*' if is_ovf else '-'),
            Fore.YELLOW if is_io                # yellow-mark access to IO
                else Fore.GREEN if is_sync
                else Fore.RED if is_write
                else Fore.WHITE,   
            CA,  #/*CA:*/
            Style.RESET_ALL,
            Fore.RED if is_write 
                else Fore.YELLOW if is_io
                else Fore.WHITE,      # red-mark Write Data access
            CD,  #/*CD:*/
            Style.RESET_ALL,
            #/*ctr:*/
            tbuf[1], ('-' if (tbuf[1] & TRACE_FLAG_RESETN) else 'R'),
            ('-' if tbuf[1] & TRACE_FLAG_IRQN else 'I'),
            ('-' if tbuf[1] & TRACE_FLAG_NMIN else 'N'),
            ('-' if tbuf[1] & TRACE_FLAG_ABORTN else 'A'),
            #/*sta:*/ 
            tbuf[0], ('r' if tbuf[0] & TRACE_FLAG_RWN else Fore.RED+'W'+Style.RESET_ALL), 
            ('-' if tbuf[0] & TRACE_FLAG_VECTPULL else 'v'), 
            ('-' if tbuf[0] & TRACE_FLAG_MLOCK else 'L'), 
            ('S' if is_sync else '-'),
            Fore.GREEN, disinst, Style.RESET_ALL
        ))


banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))

print("CPU Step:\n")
# // deactivate the reset, step the cpu
for i in range(0, step_count):
    icd.cpu_ctrl(False, True, False)
    print("Step #{:3}:  ".format(i), end='')
    banks = icd.bankregs_read(0, 2)
    read_print_trace(banks)
