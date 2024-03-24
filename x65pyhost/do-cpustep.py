#!/usr/bin/python3
import x65ftdi
from icd import *
from cpuregs import *
from cpuidec import *
import argparse
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style

colorama_init()

def parse_arguments():
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

    apa.add_argument('-o', "--force_opcode", action="store", help="Force an opcode")

    return apa.parse_args()


args = parse_arguments()
step_count = int(args.count, 0)

# define connection to the target board via the USB FTDI
#icd = ICD(x65ftdi.X65Ftdi(log_file_name='spi-log.txt'))
icd = ICD(x65ftdi.X65Ftdi())

# which CPU is installed in the target?
is_cputype02 = icd.is_cputype02()


# IO area is between 0x9F00 and 0x9FFF of the CPU memory map
IO_START_ADDR = 0x9F00
IO_END_ADDR = 0x9FFF
# the ROM and PBL area is between 0xC000 and 0xFFFF of the CPU memory map
PBL_ROM_CA_START = 0xC000

# "MAH" means Memory Address High, and it is the top 8 bits of the 21-bit SRAM address bus.
# The SRAM is 2048 kB, and the top 8 bits are used to select one of 256, 8kB blocks.
# Low memoory from 0 to 40kB = 5 memory blocks (each 8kB)
MAH_BELOW_40KB = 5
MAH_OVER_512KB = 64
MAH_BELOW_1024KB = 128
MAH_TOP = 255

# Decode the MAH, CBA and CA values into a human-readable string
# MAH: Memory Address High (top 8 bits of the 21-bit SRAM address bus)
# CBA: CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
# CA: CPU Address, 16-bit
def mah_area_name(MAH: int, CBA: int, CA: int) -> str:
    if (MAH < MAH_BELOW_40KB):
        # Low memory – fix-mapped at CPU blocks 0-4 ; unused 5-7 due to alignment (can be accessed as high-mem pages 189-191)
        mah_area = "low :{:3}".format(MAH)
    elif (MAH >= MAH_OVER_512KB) and (MAH < MAH_BELOW_1024KB):
        # ROM banks: 32 a 16kB, mapped to CPU blocks 6-7 according to REG01
        mah_area = "RomB:{:3}".format((MAH - 64)//2)
    elif (MAH == MAH_TOP) and (CBA == 0) and (CA >= PBL_ROM_CA_START):
        # special case (flag): this combination indicates an access to the PBL ROM
        mah_area = "PBL     "
    else:
        # all else -> some RAMB
        mah_area = "RAMB:{:3}".format(MAH ^ 0x80)
    
    return mah_area


def print_traceline(tbuf: ICD.TraceReg, is_upcoming=False):
    # decode instruction in the trace buffer
    disinst = decode_traced_instr(icd, tbuf, is_upcoming)

    # extract signal values from trace buffer array
    CBA = tbuf.CBA  #tbuf[6]           # CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
    MAH = tbuf.MAH  #tbuf[5]           # Memory Address High = Physical 8kB Page in SRAM
    CA = tbuf.CA  #tbuf[4] * 256 + tbuf[3]        # CPU Address, 16-bit
    CD = tbuf.CD  #tbuf[2]                # CPU Data
    is_sync = tbuf.is_sync  #(tbuf[0] & ISYNC) == ISYNC
    is_io = (CA >= IO_START_ADDR and CA <= IO_END_ADDR)
    is_write = not tbuf.is_read_nwrite  #not(tbuf[0] & TRACE_FLAG_RWN)
    is_addr_invalid = not(tbuf.is_vpa or tbuf.is_vda)   # not((tbuf[0] & TRACE_FLAG_SYNC_VPA) or (tbuf[0] & TRACE_FLAG_VDA))

    mah_area = mah_area_name(MAH, CBA, CA)

    addr_color = Fore.LIGHTBLACK_EX if is_addr_invalid \
                else Fore.YELLOW if is_io  \
                else Fore.GREEN if is_sync \
                else Fore.RED if is_write \
                else Fore.WHITE

    print("MAH:{:2x} ({})  CBA:{:2}  CA:{}{:4x}{}  CD:{}{:2x}{}  ctr:{:2x}:{}{}{}{}  sta:{:2x}:{}{}{}{}{}{}{}{}{}     {}{}{}".format(
            MAH,
            mah_area,
            (CBA if CBA==0 else Fore.BLUE+"{:2x}".format(CBA)+Style.RESET_ALL),
            addr_color,   
            CA,  #/*CA:*/
            Style.RESET_ALL,
            Fore.RED if is_write 
                else Fore.YELLOW if is_io
                else Fore.WHITE,      # red-mark Write Data access
            CD,  #/*CD:*/
            Style.RESET_ALL,
            #/*ctr:*/
            tbuf.ctr_flags, 
            ('-' if tbuf.is_resetn else 'R'),
            ('-' if tbuf.is_irqn else 'I'),
            ('-' if tbuf.is_nmin else 'N'),
            ('-' if tbuf.is_abortn else Fore.RED+'A'+Style.RESET_ALL),
            #/*sta:*/ 
            tbuf.sta_flags, 
            ('r' if tbuf.is_read_nwrite else Fore.RED+'W'+Style.RESET_ALL), 
            ('-' if tbuf.is_vectpull else Fore.YELLOW+'v'+Style.RESET_ALL),        # vector pull, active low
            ('-' if tbuf.is_mlock else 'L'),           # mem lock, active low
            ('e' if tbuf.is_emu8 else Fore.BLUE+'N'+Style.RESET_ALL),        # 'e': emulation mode, active high; 'N' native mode
            ('m' if tbuf.is_am8 else Fore.BLUE+'M'+Style.RESET_ALL),    # '816 M-flag (acumulator): 0=> 16-bit 'M', 1=> 8-bit 'm'
            ('x' if tbuf.is_xy8 else Fore.BLUE+'X'+Style.RESET_ALL),    # '816 X-flag (index regs): 0=> 16-bit 'X', 1=> 8-bit 'x'
            ('P' if tbuf.is_vpa else '-'),        # '02: SYNC, '816: VPA (valid program address)
            ('D' if tbuf.is_vda else '-'),             # '02: always 1, '816: VDA (valid data address)
            ('S' if is_sync else '-'),
            Fore.GREEN if not is_upcoming else Fore.LIGHTBLACK_EX, disinst, Style.RESET_ALL
        ))


def print_tracebuffer():
    # retrieve line from trace buffer
    is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = icd.cpu_read_trace(tbr_deq=True)
    rbuf_list = []
    while is_tbr_valid:
        # note down
        rbuf_list.append(rawbuf)
        # fetch next trace item into reg
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = icd.cpu_read_trace(tbr_deq=True)
    # print out
    for i in range(0, len(rbuf_list)):
        print("Cyc #{:5}:  ".format(i - len(rbuf_list)), end='')
        tbuf = ICD.TraceReg(rbuf_list[i])
        print_traceline(tbuf)


print('Options: block-irq={}, force-irq={}'.format(args.block_irq, args.force_irq))
print('CPU Type (from strap): {}'.format("65C02" if is_cputype02 else "65C816"))

# // deactivate the reset, STOP the cpu
icd.cpu_ctrl(False, False, False, 
                force_irq=args.force_irq, force_nmi=args.force_nmi, force_abort=args.force_abort,
                block_irq=args.block_irq, block_nmi=args.block_nmi, block_abort=args.block_abort)

banks = icd.bankregs_read(0, 2)
print('Active memory blocks: RAMBLOCK={:2x}  ROMBLOCK={:2x}'.format(banks[0], banks[1]))

print("CPU Step:\n")

cycle_i = 0
step_i = 0
cpust_ini = CpuRegs()

# for i in range(0, step_count+1):
while step_i <= step_count:
    # on the very first iteratio we don't step so that we could lift out the trace buffer first.
    if cycle_i > 0:
        # Not the first cycle.
        # Was the instruction step count reached?
        if step_i == step_count:
            # Yes => we should check the CPU state first and continue just if there is NOT a new instruction
            # upcoming.
            # read the current trace register
            is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = icd.cpu_read_trace(sample_cpu=True)
            # sanity check /assert:
            if is_valid or is_cpuruns:
                print("ERROR: Unexpected IS_VALID=TRUE or IS_CPURUNS=True: COMMUNICATION ERROR!!")
                exit(1)
            # We expect is_valid=False because this is not a trace reg from a finished CPU cycle.
            # Instead, the command sample_cpu=True just samples the stopped CPU state before it is commited.
            # Let's inspect it to see if this is already a new upcoming instruction, or contination of the old (last) one.
            tbuf = ICD.TraceReg(rawbuf)
            # is_sync = (tbuf[0] & ISYNC) == ISYNC
            if tbuf.is_sync:
                # new upcoming instruction & we have already reached the desired number of instruction steps => exit the loop here
                print()
                print("Upcoming:    ", end='')
                # decode and print cycle line
                print_traceline(tbuf, is_upcoming=True)
                break
        
        if args.force_opcode is not None:
            print("should force opcode {}".format(args.force_opcode))
            icd.cpu_force_opcode(int(args.force_opcode), False)
        
        # Now we should normally step the CPU by one cycle.
        # // deactivate the reset, STEP the cpu by 1 cycle
        icd.cpu_ctrl(False, True, False, 
                    force_irq=args.force_irq, force_nmi=args.force_nmi, force_abort=args.force_abort,
                    block_irq=args.block_irq, block_nmi=args.block_nmi, block_abort=args.block_abort)
    
    # ELSE: cycle==0 => on the very first iteration, the trace register read below is the last cycle
    # in the history. Cycles before that were recorded in the trace buffer, which is read right after that.
    
    # read the current (last) trace cycle register
    is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = icd.cpu_read_trace()
    
    # check if trace buffer memory is non-empty
    if is_tbr_valid:
        # yes, we should *first* print the trace buffer contents!
        # sanity check: this could happen just on the first for-iteration!!
        if cycle_i > 0:
            print("IS_TBR_VALID=TRUE: COMMUNICATION ERROR!!")
            exit(1)
        # print the buffer out
        print_tracebuffer()
    

    # finally, check if the original trace register was valid
    print("Cyc #{:5}:  ".format(cycle_i), end='')
    
    if is_valid:
        # is this a beginning of next instruction?
        tbuf = ICD.TraceReg(rawbuf)
        # is_sync = (tbuf[0] & ISYNC) == ISYNC
        if tbuf.is_sync:
            step_i += 1
        # decode and print cycle line
        print_traceline(tbuf)
    else:
        print("N/A")
        # sanity: this could happen just on the first for-iter!
        if cycle_i > 0:
            print("IS_VALID=FALSE: COMMUNICATION ERROR!!")
            exit(1)

    # if cycle_i == 0:
    #     # first iteration; all history up to here was printed.
    #     # Now we can get the current CPU registers
    #     cpust_ini.cpu_read_regs(icd)
    #     print(cpust_ini)

    cycle_i += 1

    # read_print_trace(banks)

# Show the final CPU State (regs)
cpust_fin = CpuRegs()
if cpust_fin.cpu_read_regs(icd):
    print(cpust_fin)
else:
    print("ERROR: CPU State read failed!!")
