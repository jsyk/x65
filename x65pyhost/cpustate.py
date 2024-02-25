from icd import *

class CpuState:
    CMD_BLOCK_WRITE = 1
    CMD_GET_PC = 2
    CMD_GET_SP = 4
    CMD_GET_FLAGS = 8
    CMD_GET_A = 16
    CMD_GET_X = 32
    CMD_GET_Y = 64
    CMD_GET_DBR = 128

    steps_readregs = [
        { 'CD': 0x08, 'sta': ICD.ISYNC, 'cmd': CMD_GET_PC  },           # PHP
        { 'sta': ICD.TRACE_FLAG_RWN, 'cmd': 0 },                # internal op (stack dec)
        { 'sta': ICD.TRACE_FLAG_VDA, 'cmd': CMD_GET_SP | CMD_GET_FLAGS },              # writing Flags to the Stack

        { 'CD': 0x28, 'sta': ICD.ISYNC, 'cmd': 0 },           # PLP
        { 'sta': ICD.TRACE_FLAG_RWN, 'cmd': 0 },                # internal op (stack inc)
        { 'sta': ICD.TRACE_FLAG_RWN, 'cmd': 0 },                # internal op (?)
        { 'sta': ICD.TRACE_FLAG_RWN | ICD.TRACE_FLAG_VDA, 'cmd': 0 },              # reading Flags from the Stack

        { 'CD': 0x85, 'sta': ICD.TRACE_FLAG_RWN | ICD.ISYNC, 'cmd': 0 },           # STA
        { 'CD': 0x02, 'sta': ICD.TRACE_FLAG_RWN | ICD.TRACE_FLAG_SYNC_VPA, 'cmd': 0 },   # arg: 0x02
        { 'sta': ICD.TRACE_FLAG_VDA, 'cmd': CMD_BLOCK_WRITE | CMD_GET_A | CMD_GET_DBR },              # writing A to the (0x02)

        { 'CD': 0x86, 'sta': ICD.TRACE_FLAG_RWN | ICD.ISYNC, 'cmd': 0 },           # STX
        { 'CD': 0x04, 'sta': ICD.TRACE_FLAG_RWN | ICD.TRACE_FLAG_SYNC_VPA, 'cmd': 0 },   # arg: 0x04
        { 'sta': ICD.TRACE_FLAG_VDA, 'cmd': CMD_BLOCK_WRITE | CMD_GET_X },              # writing X to the (0x02)

        { 'CD': 0x84, 'sta': ICD.TRACE_FLAG_RWN | ICD.ISYNC, 'cmd': 0 },           # STY
        { 'CD': 0x06, 'sta': ICD.TRACE_FLAG_RWN | ICD.TRACE_FLAG_SYNC_VPA, 'cmd': 0 },   # arg: 0x06
        { 'sta': ICD.TRACE_FLAG_VDA, 'cmd': CMD_BLOCK_WRITE | CMD_GET_Y },              # writing X to the (0x02)

        { 'CD': 0x80, 'sta': ICD.TRACE_FLAG_RWN | ICD.ISYNC, 'cmd': 0 },           # BRA
        { 'CD': 0xF6, 'sta': ICD.TRACE_FLAG_RWN | ICD.TRACE_FLAG_SYNC_VPA, 'cmd': 0 },   # arg: 0xF6
        { 'sta': ICD.TRACE_FLAG_RWN, 'cmd': 0 },                # jump
    ]

    def __init__(self) -> None:
        self.AH = None
        self.AL = None
        self.XH = None
        self.XL = None
        self.YH = None
        self.YL = None
        self.SP = None
        self.FL = None
        self.DBR = None             # Data Bank Register, 16b
        self.PC = None
    
    def cpu_read_regs(self, icd):
        # We should check the CPU state first and continue just if there is NOT a new instruction
        # upcoming.
        # read the current trace register
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, tbuf = icd.cpu_read_trace(sample_cpu=True)
        # sanity check /assert:
        if is_valid or is_cpuruns:
            print("ERROR: Unexpected IS_VALID=TRUE or IS_CPURUNS=True: Invalid CPU state / communication error!!")
            return False
        # We expect is_valid=False because this is not a trace reg from a finished CPU cycle.
        # Instead, the command sample_cpu=True just samples the stopped CPU state before it is commited.
        # Let's inspect it to see if this is already a new upcoming instruction, or contination of the old (last) one.
        is_sync = (tbuf[0] & ICD.ISYNC) == ICD.ISYNC
        if not is_sync:
            # no upcoming instruction -> we could not do the reg read sequence!
            print("ERROR: not is_sync: invalid CPU state for reading the regs!!")
            return False
        
        # CPU is stopped and awaits next opcode.
        # Ok, lets start the read sequence!
        
        step = 0

        while step < len(CpuState.steps_readregs):
            # get the step definition from the table.
            st = CpuState.steps_readregs[step]
            
            # shall we force the opcode?
            if 'CD' in st:
                icd.cpu_force_opcode(int(st['CD']), False)
            else:
                block_write = True if (st['cmd'] & CpuState.CMD_BLOCK_WRITE) != 0 else 0
                if block_write:
                    icd.cpu_force_opcode(None, True)
            
            # Now we should normally step the CPU by one cycle.
            icd.cpu_ctrl(False, True, False, 
                    force_irq=False, force_nmi=False, force_abort=False,
                    block_irq=True, block_nmi=True, block_abort=True)

            # read the current trace register
            is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, tbuf = icd.cpu_read_trace()
            
            # check if trace buffer memory is non-empty
            if is_tbr_valid:
                # yes, this is unexpected.
                print("ERROR: Unexpected is_tbr_valid during cpu_read_regs!!")
                return False

            if not is_valid:
                # no valid trace reg??!!
                print("ERROR: Unexpected (not is_valid) during cpu_read_regs!!")
                return False

            # extract signal values from trace buffer array; TBD move to a common module!!
            CBA = tbuf[6]           # CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
            MAH = tbuf[5]           # Memory Address High = SRAM Page
            CA = tbuf[4] * 256 + tbuf[3]        # CPU Address, 16-bit
            CD = tbuf[2]                # CPU Data
            is_emu = tbuf[0] & ICD.TRACE_FLAG_EF
            is_sync = (tbuf[0] & ICD.ISYNC) == ICD.ISYNC
            exp_sta = st['sta']
            exp_sync = True if (exp_sta & ICD.ISYNC) == ICD.ISYNC else False

            if exp_sync != is_sync:
                print("ERROR: sync expectation vs reality differs!!")
                return False

            cmd = st['cmd'] 
            
            if cmd & CpuState.CMD_GET_A:
                self.AL = CD
            if cmd & CpuState.CMD_GET_FLAGS:
                self.FL = CD
            if cmd & CpuState.CMD_GET_PC:
                self.PC = (CBA << 16) | CA
            if cmd & CpuState.CMD_GET_SP:
                self.SP = CA
            if cmd & CpuState.CMD_GET_X:
                self.XL = CD
            if cmd & CpuState.CMD_GET_Y:
                self.YL = CD
            if cmd & CpuState.CMD_GET_DBR:
                self.DBR = CA - 2

            step = step + 1

    def __str__(self):
        return "AL=${:02x}, XL=${:02x}, YL=${:02x}, SP=${:04x}, DBR=${:04x}, PC=${:06x}, FL=${:02x}".format(
            self.AL, self.XL, self.YL, self.SP, self.DBR, self.PC, self.FL
        )
