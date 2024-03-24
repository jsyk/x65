#
# CPU Instruction decode from a trace
# 
from icd import *

# 
# Dis-assembly map for 65C02 and 65C816 instructions, opcodes 00 to FF.
# The map is used to decode the instruction from the trace buffer.
# The map is indexed by the opcode value, and the value is a string with the instruction and its parameters.
# The parameters are encoded as follows:
#   .1  = 1 byte immediate
#   .2  = word (2B) immediate
#   .3  = 3 bytes immediate (65816)
#   :1  = 1 byte indirect address (zero page / direct page)
#   :2  = word (2B) indirect address
#   .M12 = one or 2 bytes immediate, depending on the M-flag
#   .X12 = one or 2 bytes immediate, depending on the X-flag
#   
# The instruction "?" means that the opcode is not defined for the CPU; there are some of these in 65C02.
# In 65C816, all opcodes 00-FF have defined instruction meaning.
#
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
    "LDY #.1", "LDA (.1,X)", "LDX #.1", "?", "LDY .1", "LDA .1", "LDX .1", "SMB2 .1", "TAY", "LDA #.1", "TAX", "?", "LDY .2", "LDA .2", "LDX .2", "BBS2 :1",
    "BCS :1", "LDA (.1,Y)", "LDA (.1)", "?", "LDY .1,X", "LDA .1,X", "LDX .1,Y", "SMB3 .1", "CLV", "LDA .2,Y", "TSX", "?", "LDY .2,X", "LDA .2,X", "LDX .2,Y", "BBS3 :1",
    "CPY #.1", "CMP (.1,X)", "?", "?", "CPY .1", "CMP .1", "DEC .1", "SMB4 .1", "INY", "CMP #.1", "DEX", "WAI", "CPY .2", "CMP .2", "DEC .2", "BBS4 :1",
    "BNE :1", "CMP (.1),Y", "CMP (.1)", "?", "?", "CMP .1,X", "DEC .1,X", "SMB5 .1", "CLD", "CMP .2,Y", "PHX", "STP", "?","CMP .2,X", "DEC .2,X", "BBS5 :1",
    "CPX #.1", "SBC (.1,X)", "?", "?", "CPX .1", "SBC .1", "INC .1", "SMB6 .1", "INX", "SBC #.1", "NOP", "?", "CPX .2", "SBC .2", "INC .2", "BBS6 :1", 
    "BEQ :1", "SBC (.1),Y", "SBC (.1)", "?", "?", "SBC .1,X", "INC .1,X", "SMB7 .1", "SED", "SBC .2,Y", "PLX", "?", "?", "SBC .2,X", "INC .2,X", "BBS7 :1"
]

w65c816_dismap = [
    # 0         1               2       3           4           5       6                       7
    "BRK #.1", "ORA (.1,X)", "COP #.1", "ORA .1,S", "TSB .1", "ORA .1", "ASL .1",               "ORA [.1]", "PHP", "ORA #.M12", "ASL A", "PHD", "TSB .2", "ORA .2", "ASL .2", "ORA .3",
    "BPL :1", "ORA (.1),Y", "ORA (.1)", "ORA (.1,S),Y", "TRB .1", "ORA .1,X", "ASL .1,X",       "ORA [.1],Y", "CLC", "ORA .2,Y", "INC A", "TCS", "TRB .2", "ORA .2,x", "ASL .2,x", "ORA .3,X",
    "JSR .2", "AND (.1,X)", "JSL .3", "AND .1,S", "BIT .1", "AND .1", "ROL .1",                 "AND [.1]", "PLP", "AND #.M12", "ROL A", "PLD", "BIT .2", "AND .2", "ROL .2", "AND .3",
    "BMI :1", "AND (.1),Y", "AND (.1)", "AND (.1,S),Y", "BIT .1,X", "AND .1,X", "ROL .1,X",     "AND [.1],Y", "SEC", "AND .2,Y", "DEC A", "TSC", "BIT .2,X", "AND .2,X", "ROL .2,X", "AND .3,X",
    "RTI", "EOR (.1,X)", "WDM", "EOR .1,S", "MVP .1,.1,#.1", "EOR .1", "LSR .1",                "EOR [.1]", "PHA", "EOR #.M12", "LSR A", "PHK", "JMP .2", "EOR .2", "LSR .2", "EOR .3",
    "BVC :1", "EOR (.1),Y", "EOR (.1)", "EOR (.1,S),Y", "MVN .1,.1,#.1", "EOR .1,X", "LSR .1,X","EOR [.1],Y", "CLI", "EOR .2,Y", "PHY", "TCD", "JMP .3", "EOR .2,X", "LSR .2,X", "EOR .3,X",
    "RTS", "ADC (.1,X)", "PER #:2", "ADC .1,S", "STZ .1", "ADC .1", "ROR .1",                   "ADC [.1]", "PLA", "ADC #.M12", "ROR A", "RTL", "JMP (.2)", "ADC .2", "ROR .2", "ADC .3",
    "BVS", "ADC (.1),Y", "ADC (.1)", "ADC (.1,S),Y", "STZ .1,X", "ADC .1,X", "ROR .1,X",        "ADC [.1],Y", "SEI", "ADC .2,Y", "PLY", "TDC", "JMP (.2,X)", "ADC .2,X", "ROR .2,X", "ADC .3,X",
    "BRA :1", "STA (.1,X)", "BRL :2", "STA .1,S", "STY .1", "STA .1", "STX .1",                 "STA [.1]", "DEY", "BIT #.M12", "TXA", "PHB", "STY .2", "STA .2", "STX .2", "STA .3",
    "BCC :1", "STA (.1),Y", "STA (.1)", "STA (.1,S),Y", "STY .1,X", "STA .1,X", "STX .1,Y",     "STA [.1],Y", "TYA", "STA .2,Y", "TXS", "TXY", "STZ .2", "STA .2,X", "STZ .2,X", "STA .3,X",
    "LDY #.X12", "LDA (.1,X)", "LDX #.X12", "LDA .1,S", "LDY .1", "LDA .1", "LDX .1",           "LDA [.1]", "TAY", "LDA #.M12", "TAX", "PLB", "LDY .2", "LDA .2", "LDX .2", "LDA .3",
    "BCS :1", "LDA (.1,Y)", "LDA (.1)", "LDA (.1,S),Y", "LDY .1,X", "LDA .1,X", "LDX .1,Y",     "LDA [.1],Y", "CLV", "LDA .2,Y", "TSX", "TYX", "LDY .2,X", "LDA .2,X", "LDX .2,Y", "LDA .3,X",
    "CPY #.X12", "CMP (.1,X)", "REP #.1", "CMP .1,S", "CPY .1", "CMP .1", "DEC .1",               "CMP [.1]", "INY", "CMP #.M12", "DEX", "WAI", "CPY .2", "CMP .2", "DEC .2", "CMP .3",
    "BNE :1", "CMP (.1),Y", "CMP (.1)", "CMP (.1,S),Y", "PEI #:2", "CMP .1,X", "DEC .1,X",      "CMP [.1],Y", "CLD", "CMP .2,Y", "PHX", "STP", "JML (.2)","CMP .2,X", "DEC .2,X", "CMP .3,X",
    "CPX #.X12", "SBC (.1,X)", "SEP #.1", "SBC .1,S", "CPX .1", "SBC .1", "INC .1",               "SBC [.1]", "INX", "SBC #.M12", "NOP", "XBA", "CPX .2", "SBC .2", "INC .2", "SBC .3", 
    "BEQ :1", "SBC (.1),Y", "SBC (.1)", "SBC (.1,S),Y", "PEA #:2", "SBC .1,X", "INC .1,X",      "SBC [.1],Y", "SED", "SBC .2,Y", "PLX", "XCE", "JSR (.2,X)", "SBC .2,X", "INC .2,X", "SBC .3,X"
]


# Decode instruction from the trace buffer line, if there is SYNC at this point.
# Returns string of the instruction including parameters.
# If this was not a SYNC, then return empty string.
# If the next instruction is upcoming, the tbus is just a sample of CPU state at cycle BEGINNING and CD is invalid. 
def decode_traced_instr(icd: ICD, tbuf: ICD.TraceReg, is_upcoming=False) -> str:
    # extract signal values from trace buffer array
    CBA = tbuf.CBA  #tbuf[6]           # CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
    MAH = tbuf.MAH  #tbuf[5]           # Memory Address High = SRAM Page
    CA = tbuf.CA  #tbuf[4] * 256 + tbuf[3]        # CPU Address, 16-bit
    CD = tbuf.CD  #tbuf[2]                # CPU Data
    is_sync = tbuf.is_sync  #(tbuf[0] & ISYNC) == ISYNC
    is_emu = tbuf.is_emu8   #tbuf[0] & TRACE_FLAG_EF

    mahd = None

    if is_upcoming:
        # the upcoming instruction is not yet executed/committed -> CD is invalid, and CPU is stopped at the moment.
        # Get CD from memory directly...
        # MAH is update AFTER the instruction goes through execution!
        # The MAH we have is just stale from the previous cycle, which could be a data cycle.
        # Since the processor is stopped at the moment, we read the contents of the RAMBLOCK
        # and ROMBLOCK registers from the hardware now.
        mahd = ICD.MAHDecoded.from_hw(icd)
        CD = icd.read_byte_as_cpu(CBA, mahd, CA)
        tbuf.CD = CD
    else:
        # decode MAH together with CBA and CA, this gets us the romblock/ramblock at this point of trace
        # (if they could be inferred from MAH, CBA and CA, otherwise they are invalid)
        mahd = ICD.MAHDecoded.from_trace(MAH, CBA, CA)

    if icd.is_cputype02():
        # decode 6502 instruction
        disinst = w65c02_dismap[CD] if is_sync else ""
    else:
        # decode 65816 instruction
        if is_sync:
            disinst = w65c816_dismap[CD]
            # check for opcode collisions between 6502 and 65816
            if is_emu and ((CD & 0x07) == 7):
                # yes -> warning!
                disinst += "    ; WARNING: 6502-only opcode while in the EMU mode!"
        else:
            disinst = ""
    
    # 65816: check for M (Memory+Acumulator width) and X (X and Y regs width) flags.
    # These flags are not available in 6502, but NORA ICD hw forces them to 1 (8-bit) automatically in that case,
    # so the higher-level software (disassembly) gets the correct info anyway.
    m_flag = tbuf.is_am8
    x_flag = tbuf.is_xy8

    # replace byte value
    if disinst.find('.1') >= 0:
        byteval = icd.read_byte_as_cpu(CBA, mahd, CA+1)
        disinst = disinst.replace('.1', '${:02x}'.format(byteval))

    # replace byte or word value based on Memory Flag
    if disinst.find('.M12') >= 0:
        if m_flag:
            # M=1 => 8-bit access
            byteval = icd.read_byte_as_cpu(CBA, mahd, CA+1)
            disinst = disinst.replace('.M12', '${:02x}'.format(byteval))
        else:
            # M=0 => 16-bit access
            wordval = icd.read_byte_as_cpu(CBA, mahd, CA+1) + icd.read_byte_as_cpu(CBA, mahd, CA+2)*256
            disinst = disinst.replace('.M12', '${:04x}'.format(wordval))

    # replace byte or word value based on X Flag
    if disinst.find('.X12') >= 0:
        if x_flag:
            # X=1 => 8-bit access
            byteval = icd.read_byte_as_cpu(CBA, mahd, CA+1)
            disinst = disinst.replace('.X12', '${:02x}'.format(byteval))
        else:
            # X=0 => 16-bit access
            wordval = icd.read_byte_as_cpu(CBA, mahd, CA+1) + icd.read_byte_as_cpu(CBA, mahd, CA+2)*256
            disinst = disinst.replace('.X12', '${:04x}'.format(wordval))

    # replace byte value displacement
    if disinst.find(':1') >= 0:
        byteval = icd.read_byte_as_cpu(CBA, mahd, CA+1)
        # convert to signed: negative?
        if byteval > 127:
            byteval = byteval - 256
        disinst = disinst.replace(':1', '${:x}'.format(CA+2+byteval))

    # replace word value
    if disinst.find('.2') >= 0:
        wordval = icd.read_byte_as_cpu(CBA, mahd, CA+1) + icd.read_byte_as_cpu(CBA, mahd, CA+2)*256
        disinst = disinst.replace('.2', '${:04x}'.format(wordval))

    # replace word value displacement
    if disinst.find(':2') >= 0:
        wordval = icd.read_byte_as_cpu(CBA, mahd, CA+1) + icd.read_byte_as_cpu(CBA, mahd, CA+2)*256
        # convert to signed: negative?
        if wordval > 32767:
            wordval = wordval - 32768
        disinst = disinst.replace(':2', '${:x}'.format(CA+3+wordval))

    # replace 3-byte value
    if disinst.find('.3') >= 0:
        wordval = icd.read_byte_as_cpu(CBA, mahd, CA+1) + icd.read_byte_as_cpu(CBA, mahd, CA+2)*256 + icd.read_byte_as_cpu(CBA, mahd, CA+3)*65536
        disinst = disinst.replace('.3', 'f:${:06x}'.format(wordval))

    return disinst
