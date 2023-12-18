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

apa.add_argument("-v", "--version", action="version", version = f"{apa.prog} version 1.0.0")

apa.add_argument("-I", "--force_irq", action="store_true", help="Force CPU IRQ line active.")
apa.add_argument("-i", "--block_irq", action="store_true", help="Block CPU IRQ line (deassert).")

apa.add_argument("-N", "--force_nmi", action="store_true", help="Force CPU NMI line active.")
apa.add_argument("-n", "--block_nmi", action="store_true", help="Block CPU NMI line (deassert).")

apa.add_argument("-A", "--force_abort", action="store_true", help="Force CPU ABORT line active.")
apa.add_argument("-a", "--block_abort", action="store_true", help="Block CPU ABORT line (deassert).")

apa.add_argument('count', default=32, help="Number of CPU steps to perform.")

args = apa.parse_args()

step_count = int(args.count, 0)

icd = ICD(x65ftdi.X65Ftdi())

# CPU Status flags
TRACE_FLAG_RWN =		1
TRACE_FLAG_EF =         2
TRACE_FLAG_VDA =        4
TRACE_FLAG_VECTPULL =	8
TRACE_FLAG_MLOCK =		16
TRACE_FLAG_SYNC_VPA =   32
TRACE_FLAG_CSOB_M =     64
TRACE_FLAG_RDY =        128
# CPU Control flags
TRACE_FLAG_CSOB_X =     16      # status
TRACE_FLAG_RESETN =     8
TRACE_FLAG_IRQN =       4
TRACE_FLAG_NMIN =       2
TRACE_FLAG_ABORTN =     1

ISYNC = TRACE_FLAG_VDA | TRACE_FLAG_SYNC_VPA            # both must be set to indicate first byte of an instruction

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

# Read a byte via ICD memory access from the target.
# The address is identified by captured MAH and CA.
# MAH is decoded into the bank address.
def read_byte_as_cpu(MAH, CA):
    # rambank = banks[0]
    # rombank = banks[1]
    if 0 <= CA < 2:
        # bank regs
        rdata = icd.bankregs_read(CA, 1)
    elif CA < 0x9F00:
        # CPU low memory starts at sram fix 0x170000
        rdata = icd.sram_blockread(CA + 0x170000, 1)
    elif 0xA000 <= CA < 0xC000:
        # CPU RAM Bank starts at sram fix 0x000
        rambank = MAH
        rdata = icd.sram_blockread((CA - 0xA000) + rambank*ICD.PAGESIZE, 1)
    elif 0xC000 <= CA:
        # CPU ROM bank
        rombank = (MAH >> 1) & 0x1F     # tbd: does not cover the PBL BANK!!
        if rombank < 32:
            # CPU ROM bank starts at sram fix 0x180000
            rdata = icd.sram_blockread((CA - 0xC000) + 0x180000 + rombank*2*ICD.PAGESIZE, 1)
        else:
            # bootrom inside of NORA
            rdata = icd.bootrom_blockread((CA - 0xC000), 1)
    return rdata[0]


# def read_print_trace(banks):
#     is_valid, is_ovf, is_tbr_valid, is_tbr_full, tbuf = icd.cpu_read_trace()
#     if is_valid:
#         print_traceline(tbuf)
#     else:
#         print("N/A")


def print_traceline(tbuf):
    # extract signal values from trace buffer array
    CBA = tbuf[6]
    MAH = tbuf[5]
    CA = tbuf[4] * 256 + tbuf[3]
    CD = tbuf[2]
    is_sync = (tbuf[0] & ISYNC) == ISYNC
    disinst = w65c02_dismap[tbuf[2]] if is_sync else ""

    # replace byte value
    if disinst.find('.1') >= 0:
        byteval = read_byte_as_cpu(MAH, CA+1)
        disinst = disinst.replace('.1', '${:x}'.format(byteval))
    
    # replace byte value displacement
    if disinst.find(':1') >= 0:
        byteval = read_byte_as_cpu(MAH, CA+1)
        # convert to signed: negative?
        if byteval > 127:
            byteval = byteval - 256
        disinst = disinst.replace(':1', '${:x}'.format(CA+2+byteval))

    # replace word value
    if disinst.find('.2') >= 0:
        wordval = read_byte_as_cpu(MAH, CA+1) + read_byte_as_cpu(MAH, CA+2)*256
        disinst = disinst.replace('.2', '${:x}'.format(wordval))

    is_io = (CA >= 0x9F00 and CA <= 0x9FFF)
    is_write = not(tbuf[0] & TRACE_FLAG_RWN)
    is_addr_invalid = not((tbuf[0] & TRACE_FLAG_SYNC_VPA) or (tbuf[0] & TRACE_FLAG_VDA))

    if (MAH <= 183) or (188 <= MAH <= 191):
        # High memory – mapped to CPU page 5 according to REG00 (RAMBANK)
        mah_area = "RAMB:{:3}".format(MAH)
    elif MAH <= 191:
        # Low memory – fix-mapped at CPU pages 0-4 ; unused 5-7 due to alignment (can be accessed as high-mem pages 189-191)
        mah_area = "low :{:3}".format(MAH)
    else:
        # >= 192 to 255
        # ROM banks: 32 a 16kB, mapped to CPU pages 6-7 according to REG01
        mah_area = "ROMB:{:3}".format(MAH - 192)

    addr_color = Fore.LIGHTBLACK_EX if is_addr_invalid \
                else Fore.YELLOW if is_io  \
                else Fore.GREEN if is_sync \
                else Fore.RED if is_write \
                else Fore.WHITE

    print("MAH:{:2x} ({})  CBA:{:2x}  CA:{}{:4x}{}  CD:{}{:2x}{}  ctr:{:2x}:{}{}{}{}  sta:{:2x}:{}{}{}{}{}{}{}{}{}     {}{}{}".format(
            MAH,
            mah_area,
            CBA,
            addr_color,   
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
            ('-' if tbuf[0] & TRACE_FLAG_VECTPULL else 'v'),        # vector pull, active low
            ('-' if tbuf[0] & TRACE_FLAG_MLOCK else 'L'),           # mem lock, active low
            ('E' if tbuf[0] & TRACE_FLAG_EF else '-'),              # emulation mode, active high
            ('m' if tbuf[0] & TRACE_FLAG_CSOB_M else 'M'),          # '816 M-flag (acumulator): 0=> 16-bit, 1=> 8-bit
            ('x' if tbuf[1] & TRACE_FLAG_CSOB_X else 'X'),          # '816 X-flag (index regs): 0=> 16-bit, 1=> 8-bit
            ('P' if tbuf[0] & TRACE_FLAG_SYNC_VPA else '-'),        # '02: SYNC, '816: VPA (valid program address)
            ('D' if tbuf[0] & TRACE_FLAG_VDA else '-'),             # '02: always 1, '816: VDA (valid data address)
            ('S' if is_sync else '-'),
            Fore.GREEN, disinst, Style.RESET_ALL
        ))


def print_tracebuffer():
    # retrieve line from trace buffer
    is_valid, is_ovf, is_tbr_valid, is_tbr_full, tbuf = icd.cpu_read_trace(tbr_deq=True)
    tbuf_list = []
    while is_tbr_valid:
        # note down
        tbuf_list.append(tbuf)
        # fetch next trace item into reg
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, tbuf = icd.cpu_read_trace(tbr_deq=True)
    # print out
    for i in range(0, len(tbuf_list)):
        print("Step #{:5}:  ".format(i - len(tbuf_list)), end='')
        print_traceline(tbuf_list[i])


banks = icd.bankregs_read(0, 2)
print('Options: block-irq={}, force-irq={}'.format(args.block_irq, args.force_irq))
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))

print("CPU Step:\n")

# // deactivate the reset, STOP the cpu
icd.cpu_ctrl(False, False, False, 
                force_irq=args.force_irq, force_nmi=args.force_nmi, force_abort=args.force_abort,
                block_irq=args.block_irq, block_nmi=args.block_nmi, block_abort=args.block_abort)

for i in range(0, step_count+1):
    if i > 0:
        # // deactivate the reset, STEP the cpu by 1 cycle
        icd.cpu_ctrl(False, True, False, 
                    force_irq=args.force_irq, force_nmi=args.force_nmi, force_abort=args.force_abort,
                    block_irq=args.block_irq, block_nmi=args.block_nmi, block_abort=args.block_abort)
    # determine the current bank; TBD remove
    # banks = icd.bankregs_read(0, 2)
    # read the current trace register
    is_valid, is_ovf, is_tbr_valid, is_tbr_full, tbuf = icd.cpu_read_trace()
    # check if trace buffer memory is non-empty
    if is_tbr_valid:
        # yes, we should first print the trace buffer contents!
        # sanity check: this could happen just on the first for-iteration!!
        if i > 0:
            print("IS_TBR_VALID=TRUE: COMMUNICATION ERROR!!")
            exit(1)
        print_tracebuffer()

    # finally, check if the original trace register was valid
    print("Step #{:5}:  ".format(i), end='')
    if is_valid:
        print_traceline(tbuf)
    else:
        print("N/A")
        # sanity: this could happen just on the first for-iter!
        if i > 0:
            print("IS_VALID=FALSE: COMMUNICATION ERROR!!")
            exit(1)

    # read_print_trace(banks)
