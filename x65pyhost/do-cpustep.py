#!/usr/bin/python3
import x65ftdi
from icd import *

icd = ICD(x65ftdi.X65Ftdi())


TRACE_FLAG_RWN =		1
TRACE_FLAG_VECTPULL =	8
TRACE_FLAG_MLOCK =		16
TRACE_FLAG_SYNC =		32

w65c02_dismap = [
    "BRK s", "ORA (zp,X)", "?", "?", "TSB zp", "ORA zp", "ASL zp", "RMB0 zp", "PHP s", "ORA #", "ASL A", "?", "TSB A", "ORA a", "ASL a", "BBR0 r",
    "BPL r", "ORA (zp),Y", "ORA (zp)", "?", "TRB zp", "ORA zp,X", "ASL zp,X", "RMB1 zp", "CLC i", "ORA a,Y", "INC A", "?", "TRB a", "ORA a,x", "ASL a,x", "BBR1 r",
    "JSR a", "AND (zp,X)", "?", "?", "BIT zp", "AND zp", "ROL zp", "RMB2 zp", "PLP s", "AND #", "ROL A", "?", "BIT a", "AND a", "ROL a", "BBR2 r",
    "BMI r", "AND (zp),Y", "AND (zp)", "?", "BIT zp,X", "AND zp,X", "ROL zp,X", "RMB3 zp", "SEC i", "AND a,Y", "DEC A", "?", "BIT a,X", "AND a,X", "ROL a,X", "BBR3 r",
    "RTI s", "EOR (zp,X)", "?", "?", "?", "EOR zp", "LSR zp", "RMB4 zp", "PHA s", "EOR #", "LSR A", "?", "JMP a", "EOR a", "LSR a", "BBR4 r",
    "BVC r", "EOR (zp),Y", "EOR (zp)", "?", "?", "EOR zp,X", "LSR zp,X", "RMB5 zp", "CLI i", "EOR a,Y", "PHY s", "?", "?", "EOR a,X", "LSR a,X", "BBR5 r",
    "RTS s", "ADC (zp,X)", "?", "?", "STZ zp", "ADC zp", "ROR zp", "RMB6 zp", "PLA s", "ADC #", "ROR A", "?", "JMP (a)", "ADC a", "ROR a", "BBR6 r",
    "BVS s", "ADC (zp),Y", "ADC (zp)", "?", "STZ zp,X", "ADC zp,X", "ROR zp,X", "RMB7 zp", "SEI i", "ADC a,Y", "PLY s", "?", "JMP (a,X)", "ADC a,X", "ROR a,X", "BBR7 r",
    "BRA r", "STA (zp,X)", "?", "?", "STY zp", "STA zp", "STX zp", "SMB0 zp", "DEY i", "BIT #", "TXA i", "?", "STY a", "STA a", "STX a", "BBS0 r",
    "BCC r", "STA (zp),Y", "STA (zp)", "?", "STY zp,X", "STA zp,X", "STX zp,Y", "SMB1 zp", "TYA i", "STA a,Y", "TXS i", "?", "STZ a", "STA a,X", "STZ a,X", "BBS1 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    # // TBD... lines B-F
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r"
]


def read_print_trace():
    tbuflen = 5
    is_valid, is_ovf, tbuf = icd.cpu_read_trace(tbuflen)

    print("TraceBuf: V:{} O:{}  CA:{:4x}  CD:{:2x}  ctr:{:2x}  sta:{:2x}:{}{}{}{}     {}".format(
            ('*' if is_valid else '-'),
            ('*' if is_ovf else '-'),
            tbuf[4] * 256 + tbuf[3],  #/*CA:*/
            tbuf[2],  #/*CD:*/
            tbuf[1],  #/*ctr:*/
            #/*sta:*/ 
            tbuf[0], ('r' if tbuf[0] & TRACE_FLAG_RWN else 'W'), 
            ('-' if tbuf[0] & TRACE_FLAG_VECTPULL else 'v'), 
            ('-' if tbuf[0] & TRACE_FLAG_MLOCK else 'L'), 
            ('S' if tbuf[0] & TRACE_FLAG_SYNC else '-'),
            (w65c02_dismap[tbuf[2]] if tbuf[0] & TRACE_FLAG_SYNC else "")
        ))


print("CPU Step:\n")
# // deactivate the reset, step the cpu
for i in range(0, 32):
    icd.cpu_ctrl(False, True, False)
    print("Step #{:3}:  ".format(i), end='')
    read_print_trace()
