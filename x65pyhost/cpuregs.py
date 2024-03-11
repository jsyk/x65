from icd import *

# 
# This class represents the 6502/65816 CPU architected registers
# and contains methods to read/write them via the ICD functions of NORA FPGA.
# 
class CpuRegs:
    # CPU status flasg for the opcode forcing table below
    STA_ISYNC = 1
    STA_AM16 = 2
    STA_XY16 = 4

    # command flags for the opcode forcing table below
    CMD_BLOCK_WRITE = 1
    CMD_GET_PC = 2
    CMD_GET_SP = 4
    CMD_GET_FLAGS = 8
    CMD_GET_A = 16
    CMD_GET_X = 32
    CMD_GET_Y = 64
    CMD_GET_DBR = 128           # Data Bank Register, 8-bit
    CMD_GET_DPR = 256           # Direct Page Register, 16-bit
    CMD_GET_AH = 512
    CMD_GET_XH = 1024
    CMD_GET_YH = 2048

    # table defines the opcode steps to readout all the CPU regs
    steps_readregs = [
        { 'CD': 0x08,   'sta': STA_ISYNC,   'cmd': CMD_GET_PC  },           # PHP
        {               'sta': 0,           'cmd': 0 },                # internal op (stack dec)
        {               'sta': 0,           'cmd': CMD_GET_SP | CMD_GET_FLAGS },              # writing Flags to the Stack

        { 'CD': 0x28,   'sta': STA_ISYNC,   'cmd': 0 },           # PLP
        {               'sta': 0,           'cmd': 0 },                # internal op (stack inc)
        {               'sta': 0,           'cmd': 0 },                # internal op (?)
        {               'sta': 0,           'cmd': 0 },              # reading Flags from the Stack

        { 'CD': 0x85,   'sta': STA_ISYNC,   'cmd': 0 },           # STA
        { 'CD': 0x02,   'sta': 0,           'cmd': 0 },   # arg: 0x02
        {               'sta': 0,           'cmd': CMD_BLOCK_WRITE | CMD_GET_A | CMD_GET_DPR },              # writing A to the (0x02)
        {               'sta': STA_AM16,    'cmd': CMD_BLOCK_WRITE | CMD_GET_AH },              # writing AH to the (0x03)

        { 'CD': 0x8E,   'sta': STA_ISYNC,   'cmd': 0 },           # STX
        { 'CD': 0x40,   'sta': 0,           'cmd': 0 },   # arg: 0x40
        { 'CD': 0x44,   'sta': 0,           'cmd': 0 },   # arg: 0x44
        {               'sta': 0,           'cmd': CMD_BLOCK_WRITE | CMD_GET_X | CMD_GET_DBR },              # writing X to the (0x4440)
        {               'sta': STA_XY16,    'cmd': CMD_BLOCK_WRITE | CMD_GET_XH  },              # writing XH to the (0x4441)

        { 'CD': 0x84,   'sta': STA_ISYNC,   'cmd': 0 },           # STY
        { 'CD': 0x06,   'sta': 0,           'cmd': 0 },   # arg: 0x06
        {               'sta': 0,           'cmd': CMD_BLOCK_WRITE | CMD_GET_Y },              # writing X to the (0x02)
        {               'sta': STA_XY16,    'cmd': CMD_BLOCK_WRITE | CMD_GET_YH  },              # writing YH to the (0x4441)

        { 'CD': 0x80,   'sta': STA_ISYNC,   'cmd': 0 },           # BRA
        { 'CD': 0xF5,   'sta': 0,           'cmd': 0 },   # arg: 0xF5
        {               'sta': 0,           'cmd': 0 },                # jump, internal op.
    ]

    def __init__(self) -> None:
        self.AH = None
        self.AL = None
        self.XH = None
        self.XL = None
        self.YH = None
        self.YL = None
        self.SP = None              # Stack pointer, 16b (native), 8b in Emu mode
        self.FL = None              # Flags, 8b
        self.EMU = None             # Emulation mode flag, 0/1
        self.DBR = None             # Data Bank Register, 8b
        self.DPR = None             # Data Page Register, 16b
        self.PC = None              # Program counter incl. PBR, 24-bit
    
    def cpu_read_regs(self, icd):
        # We should check the CPU state first and continue just if there is NOT a new instruction
        # upcoming.
        # read the current trace register
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = icd.cpu_read_trace(sample_cpu=True)
        # is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, tbuf = icd.cpu_get_status()
        # sanity check /assert:
        if is_valid or is_cpuruns:
            print("ERROR: Unexpected IS_VALID=TRUE or IS_CPURUNS=True: Invalid CPU state / communication error!!")
            return False
        # We expect is_valid=False because this is not a trace reg from a finished CPU cycle.
        # Instead, the command sample_cpu=True just samples the stopped CPU state before it is commited.
        tbuf = ICD.TraceReg(rawbuf)
        # Let's inspect it to see if this is already a new upcoming instruction, or contination of the old (last) one.
        # is_sync = (tbuf[0] & ICD.TRACE_FLAG_ISYNC) == ICD.TRACE_FLAG_ISYNC
        if not tbuf.is_sync:
            # no upcoming instruction -> we could not do the reg read sequence!
            print("ERROR: not is_sync: invalid CPU state for reading the regs!!")
            return False
        
        # CPU is stopped and awaits next opcode.
        # Ok, lets start the read sequence!
        
        step = 0
        is_am16 = False
        is_xy16 = False

        while step < len(CpuRegs.steps_readregs):
            # get the step definition from the table.
            st = CpuRegs.steps_readregs[step]
            # expected CPU State value
            exp_sta = st['sta']
            exp_sync = True if (exp_sta & CpuRegs.STA_ISYNC) == CpuRegs.STA_ISYNC else False
            exp_am16 = True if (exp_sta & CpuRegs.STA_AM16) else False
            exp_xy16 = True if (exp_sta & CpuRegs.STA_XY16) else False

            if exp_am16 and not is_am16:
                # the current Step expect M16 (A16), but reality is M8 (A8) => skip this step!
                step = step + 1
                continue
                
            if exp_xy16 and not is_xy16:
                # the current Step expect X16, but reality is X8 => skip this step!
                step = step + 1
                continue
            
            # shall we force the opcode?
            if 'CD' in st:
                icd.cpu_force_opcode(int(st['CD']), False)
            else:
                block_write = True if (st['cmd'] & CpuRegs.CMD_BLOCK_WRITE) != 0 else 0
                if block_write:
                    icd.cpu_force_opcode(None, True)
            
            # Now we should normally step the CPU by one cycle.
            icd.cpu_ctrl(False, True, False, 
                    force_irq=False, force_nmi=False, force_abort=False,
                    block_irq=True, block_nmi=True, block_abort=True)

            # read the current trace register
            is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = icd.cpu_read_trace()
            
            # check if trace buffer memory is non-empty
            if is_tbr_valid:
                # yes, this is unexpected.
                print("ERROR: Unexpected is_tbr_valid during cpu_read_regs!!")
                return False

            if not is_valid:
                # no valid trace reg??!!
                print("ERROR: Unexpected (not is_valid) during cpu_read_regs!!")
                return False

            # extract signal values from raw trace buffer array; TBD move to a common module!!
            tbuf = ICD.TraceReg(rawbuf)

            # CBA = tbuf[6]           # CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
            # MAH = tbuf[5]           # Memory Address High = SRAM Page
            # CA = tbuf[4] * 256 + tbuf[3]        # CPU Address, 16-bit
            # CD = tbuf[2]                # CPU Data
            # self.EMU = 1 if (tbuf[0] & ICD.TRACE_FLAG_EF) else 0
            # is_sync = (tbuf[0] & ICD.TRACE_FLAG_ISYNC) == ICD.TRACE_FLAG_ISYNC
            # is_am16 = not ((tbuf[0] & ICD.TRACE_FLAG_CSOB_M) == ICD.TRACE_FLAG_CSOB_M)
            # is_xy16 = not ((tbuf[1] & ICD.TRACE_FLAG_CSOB_X)  == ICD.TRACE_FLAG_CSOB_X)

            self.EMU = tbuf.is_emu8
            is_am16 = not tbuf.is_am8
            is_xy16 = not tbuf.is_xy8

            # check if SYNC/notSYNC is as it should be
            if exp_sync != tbuf.is_sync:
                print("ERROR: sync expectation vs reality differs!!")
                print("    step={}, sta={:2x}, ctr={:2x}, CD={:2x}".format(step, tbuf.sta_flags, tbuf.ctr_flags, tbuf.CD))
                return False

            cmd = st['cmd'] 
            # decode commands
            if cmd & CpuRegs.CMD_GET_A:
                self.AL = tbuf.CD
            if cmd & CpuRegs.CMD_GET_AH:
                self.AH = tbuf.CD
            if cmd & CpuRegs.CMD_GET_FLAGS:
                self.FL = tbuf.CD
            if cmd & CpuRegs.CMD_GET_PC:
                self.PC = (tbuf.CBA << 16) | tbuf.CA
            if cmd & CpuRegs.CMD_GET_SP:
                self.SP = tbuf.CA
            if cmd & CpuRegs.CMD_GET_X:
                self.XL = tbuf.CD
            if cmd & CpuRegs.CMD_GET_XH:
                self.XH = tbuf.CD
            if cmd & CpuRegs.CMD_GET_Y:
                self.YL = tbuf.CD
            if cmd & CpuRegs.CMD_GET_YH:
                self.YH = tbuf.CD
            if cmd & CpuRegs.CMD_GET_DPR:
                self.DPR = tbuf.CA - 2
            if cmd & CpuRegs.CMD_GET_DBR:
                self.DBR = tbuf.CBA

            step = step + 1

    def hex2(self, h, replace='.'):
        if h is None:
            return replace + replace
        else:
            return "{:02x}".format(h)
    
    def __str__(self):
        return "A=${}{:02x}, X=${}{:02x}, Y=${}{:02x}, SP=${:04x}, DPR=${:04x}, DBR=${:02x}, PC=${:06x}, FL=${:02x}={}{}{}{}{}{}{}{}/{}".format(
            self.hex2(self.AH), self.AL, 
            self.hex2(self.XH), self.XL, 
            self.hex2(self.YH), self.YL, 
            self.SP, self.DPR, self.DBR, self.PC, self.FL,
            'N' if self.FL & 128 else '-',
            'V' if self.FL & 64 else '-',
            '1' if self.EMU else ('m' if self.FL & 32 else 'M'),
            'B' if self.EMU and (self.FL & 16) else ('-' if self.EMU else ('x' if self.FL & 16 else 'X')),
            'D' if self.FL & 8 else '-',
            'I' if self.FL & 4 else '-',
            'Z' if self.FL & 2 else '-',
            'C' if self.FL & 1 else '-',
            'emu' if self.EMU else 'Nat'
        )
