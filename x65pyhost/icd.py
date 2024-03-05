# import x65ftdi
import random

class ICD:
    # Definition of ICD protocol:
    # First byte low nible = command:
    CMD_GETSTATUS =	0x0
    CMD_BUSMEM_ACC = 0x1
    CMD_CPUCTRL = 0x2
    CMD_READTRACE =	0x3
    CMD_FORCECDB = 0x6

    # First byte high nible = options:
    # ... in case of CMD_BUSMEM_ACC:
    nSRAM_OTHER_BIT =	4
    nWRITE_READ_BIT =	5
    ADR_INC_BIT =		6

    ICD_OTHER_BOOTROM_BIT = 20
    ICD_OTHER_BANKREG_BIT = 19
    ICD_OTHER_IOREG_BIT = 18

    # Composite commands
    ICD_SRAM_WRITE	= (CMD_BUSMEM_ACC | (1 << ADR_INC_BIT))
    ICD_SRAM_READ =	(CMD_BUSMEM_ACC | (1 << nWRITE_READ_BIT) | (1 << ADR_INC_BIT))

    ICD_OTHER_WRITE = (CMD_BUSMEM_ACC | (1 << nSRAM_OTHER_BIT) | (1 << ADR_INC_BIT))
    ICD_OTHER_READ = (CMD_BUSMEM_ACC | (1 << nSRAM_OTHER_BIT) | (1 << nWRITE_READ_BIT) | (1 << ADR_INC_BIT))

    # Aux definitions
    BLOCKSIZE = 256             # misnomer => PAGE
    PAGESIZE = 8192             # misnomer => BLOCK
    MAXREQSIZE = 16384
    SIZE_2MB =	(2048 * 1024)

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


    def __init__(self, com):
        # communication link - x65ftdi
        self.com = com

    # Read bytes from X65 bus
    def busread(self, cmd, maddr, n):
        hdr = bytes( [cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF, 0x00 ] )
        self.com.icd_chip_select()
        rxdata = self.com.spiexchange(hdr, n+len(hdr))
        # slave.write(hdr, start=False, stop=False, droptail=1)
        # rxdata = slave.read(n, start=False, stop=False)
        self.com.icd_chip_deselect()
        return rxdata[5:]

    # Write data bytes to X65 bus
    def buswrite(self, cmd, maddr, data):
        hdr = bytes([cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF ])
        self.com.icd_chip_select()
        self.com.spiwriteonly(hdr)
        self.com.spiwriteonly(data)
        self.com.icd_chip_deselect()


    # read from BLOCKREGs
    def bankregs_read(self, maddr, n):
        maddr &= 1
        maddr |= (1 << ICD.ICD_OTHER_BANKREG_BIT)
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    # write to BLOCKREGs
    def bankregs_write(self, maddr, data):
        maddr &= 1
        maddr |= (1 << ICD.ICD_OTHER_BANKREG_BIT)
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)

    # read bytes from IO registers
    def ioregs_read(self, maddr, n):
        maddr &= 0xFF
        # The 0x9F helps NORA to position Scratchpad area in SRAM for the ICD access
        maddr |= (1 << ICD.ICD_OTHER_IOREG_BIT) | 0x9F00
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    # write bytes to IO registers
    def ioregs_write(self, maddr, data):
        maddr &= 0xFF
        # The 0x9F helps NORA to position Scratchpad area in SRAM for the ICD access
        maddr |= (1 << ICD.ICD_OTHER_IOREG_BIT) | 0x9F00
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)

    # write 1byte to IO register
    def iopoke(self, addr, data):
        return self.ioregs_write(addr, [data])

    # read 1byte from IO register
    def iopeek(self, addr):
        data = self.ioregs_read(addr, 1)
        return data[0]


    def bootrom_blockread(self, maddr, n):
        maddr &= 0xFFF
        maddr |= (1 << ICD.ICD_OTHER_BOOTROM_BIT)
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    def bootrom_blockwrite(self, maddr, data):
        maddr &= 0xFFF
        maddr |= (1 << ICD.ICD_OTHER_BOOTROM_BIT)
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)


    def sram_blockwrite(self, maddr, data):
        k = 0
        while len(data)-k > ICD.MAXREQSIZE:
            self.buswrite(ICD.ICD_SRAM_WRITE, maddr+k, data[k:k+ICD.MAXREQSIZE])
            k = k + ICD.MAXREQSIZE
        self.buswrite(ICD.ICD_SRAM_WRITE, maddr+k, data[k:])

    def sram_blockread(self, maddr, n):
        return self.busread(ICD.ICD_SRAM_READ, maddr, n)

    def sram_memtest(self, seed, mstart, mbytes):
        # uint8_t buf[BLOCKSIZE];
        blocks = int(mbytes / ICD.BLOCKSIZE)

        print("SRAM Memtest from 0x{:x} to 0x{:x}, rand seed 0x{:x}".format(
                mstart, mstart + mbytes - 1, seed));

        # restart rand sequence
        random.seed(seed)

        for b in range(0, blocks):
            buf = random.randbytes(ICD.BLOCKSIZE)
            if ((b * ICD.BLOCKSIZE) % ICD.PAGESIZE == 0):
                print("  Writing block 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
                        int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE), int((b+1) + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE - 1))
            
            self.sram_blockwrite(mstart + b * ICD.BLOCKSIZE, buf);
        
        # restart rand sequence
        random.seed(seed)
        
        errors = 0

        for b in range(0, blocks):
            if ((b * ICD.BLOCKSIZE) % ICD.PAGESIZE == 0):
                print("  Reading block 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
                        int(b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE, int((b+1) + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE - 1))
            
            buf1 = self.sram_blockread(mstart + b * ICD.BLOCKSIZE, ICD.BLOCKSIZE)
            buf2 = random.randbytes(ICD.BLOCKSIZE)
            # print('buf1={}'.format(buf1.hex()))
            # print('buf2={}'.format(buf2.hex()))
            if buf1 != buf2:
                errors += 1
                print("  Error in block 0x{:x} (0x{:x} to 0x{:x})!".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
                            mstart + b*ICD.BLOCKSIZE, mstart + (b-1)*ICD.BLOCKSIZE - 1))

        print("Memtest done with {} errors.".format(errors))
        return errors


    # 
    # Execute the CPU CTRL command in the ICD.
    # This allows to start/stop the CPU, and single-step (1 cpu cycle) the CPU.
    # Additionally various events (IRQ, NMI, ...) could be forced to the CPU
    # or blocked from the CPU.
    # 
    def cpu_ctrl(self, run_cpu, cstep_cpu, reset_cpu, 
                    force_irq=False, force_nmi=False, force_abort=False, 
                    block_irq=False, block_nmi=False, block_abort=False):
        #  *      |       0x2         CPU CTRL
        #  *      `----------------------->   [4]     0 => Stop CPU, 1 => RUN CPU (indefinitely)
        #  *                                  [5]     0 => no-action, 1 => Single-Cycle-Step CPU (it must be stopped prior)
        #  *                          2nd byte = forcing or blocking of CPU control signals
        #  *                                  [0]     0 => reset not active, 1 => CPU reset active!
        #  *                                  [1]     0 => IRQ not active, 1 => IRQ forced!
        #  *                                  [2]     0 => NMI not active, 1 => NMI forced!
        #  *                                  [3]     0 => ABORT not active, 1 => ABORT forced!
        #  *                                  [4]     0 => IRQ not blocked, 1 => IRQ blocked!
        #  *                                  [5]     0 => NMI not blocked, 1 => NMI blocked!
        #  *                                  [6]     0 => ABORT not blocked, 1 => ABORT blocked!
        #  *                                  [7]     unused
        run_cpu = 1 if run_cpu else 0
        cstep_cpu = 1 if cstep_cpu else 0
        cpu_sig = 1 if reset_cpu else 0
        cpu_sig |= 2 if force_irq else 0
        cpu_sig |= 4 if force_nmi else 0
        cpu_sig |= 8 if force_abort else 0
        cpu_sig |= 16 if block_irq else 0
        cpu_sig |= 32 if block_nmi else 0
        cpu_sig |= 64 if block_abort else 0

        hdr = bytes([ ICD.CMD_CPUCTRL | (run_cpu << 4) | (cstep_cpu << 5), cpu_sig ])

        self.com.icd_chip_select()
        self.com.spiwriteonly(hdr)
        self.com.icd_chip_deselect()


    # send the
    # *      |       0x6         FORCE CPU DATA BUS
    # *      `----------------------->   [4]     1 => force opcode as the 2nd byte, 0 => ignore the second byte / no opcode force.
    # *                                  [5]     1 => ignore Writes, 0 => normal writes.
    # *                          RX 2nd byte = byte for the CPU DB (opcode or opcode arg)
    def cpu_force_opcode(self, forced_db, ignore_cpu_writes):
        is_forced_db = 1 if forced_db is not None else 0
        forced_db = 0 if forced_db is None else forced_db
        ignore_cpu_writes = 1 if ignore_cpu_writes else 0
        
        hdr = bytes([ ICD.CMD_FORCECDB | (is_forced_db << 4) | (ignore_cpu_writes << 5), forced_db ])

        self.com.icd_chip_select()
        self.com.spiwriteonly(hdr)
        self.com.icd_chip_deselect()


    # Read CPU Status, and LSB of Trace Register.
    def cpu_read_status(self):
        #  *              0x0         GETSTATUS
        #  *                          TX:2nd byte = dummy
        #  *                          TX:3rd byte = status of CPU / ICD
        #  *                                  [0]    TRACE-REG VALID
        #  *                                  [1]    TRACE-REG OVERFLOWED
        #  *                                  [2]    TRACE-BUF NON-EMPTY (note: status before a dequeue or clear!)
        #  *                                  [3]    TRACE-BUF FULL (note: status before a dequeue or clear!)
        #  *                                  [4]    CPU-RUNNING? If yes (1), then trace register reading is not allowed (returns dummy)!!
        #  *                                          reserved = [7:5]
        #  *                          TX:4th byte = trace REGISTER contents: LSB byte (just read, not shifting!!)
        #                               /*dummy*/
        hdr = bytes([ ICD.CMD_READTRACE, 0  ])

        self.com.icd_chip_select();
        treglen = 1
        rxdata = self.com.spiexchange(hdr, treglen+1+len(hdr))
        self.com.icd_chip_deselect()

        is_valid = rxdata[2] & 1            # TRACE-REG VALID?  
        is_ovf = rxdata[2] & 2              # TRACE-REG OVERFLOWED?
        is_tbr_valid = rxdata[2] & 4        # TRACE-BUFFER NON-EMPTY?
        is_tbr_full = rxdata[2] & 8         # TRACE-BUFFER FULL?
        is_cpuruns = rxdata[2] & 16         # CPU-RUNNING?
        # print('icd_cpu_read_trace got {}'.format(rxdata.hex()))
        return (is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rxdata[3:])


    # Read CPU Trace Register.
    def cpu_read_trace(self, tbr_deq=False, tbr_clear=False, treglen=7, sample_cpu=False):
        #  *      |       0x3         READ CPU TRACE REG
        #  *      `----------------------->   [4]     1 => Dequeue next trace-word from trace-buffer into the trace-reg
        #  *                                  [5]     1 => Clear the trace buffer.
        #  *                                  [6]     1 => Sample the trace reg from actual CPU state; only allowed if the CPU is stopped,
        #  *                                               and the trace reg should be empty to avoid loosing any previous data.
        #  *                          TX:2nd byte = dummy
        #  *                          TX:3rd byte = status of trace buffer:
        #  *                                  [0]    TRACE-REG VALID
        #  *                                  [1]    TRACE-REG OVERFLOWED
        #  *                                  [2]    TRACE-BUF NON-EMPTY
        #  *                                  [3]    TRACE-BUF FULL
        #  *                                  [4]    CPU-RUNNING? If yes (1), then trace register reading is not allowed (returns dummy)!!
        #  *                                          reserved = [7:5]
        #  *                          TX:4th, 5th... byte = trace REGISTER contents, starting from LSB byte.
        tbr_deq = 1 if tbr_deq else 0
        tbr_clear = 1 if tbr_clear else 0
        sample_cpu = 1 if sample_cpu else 0
        #                               /*dummy*/
        hdr = bytes([ ICD.CMD_READTRACE | (tbr_deq << 4) | (tbr_clear << 5) | (sample_cpu << 6), 0  ])

        self.com.icd_chip_select();
        rxdata = self.com.spiexchange(hdr, treglen+1+len(hdr))
        self.com.icd_chip_deselect()

        is_valid = rxdata[2] & 1            # TRACE-REG VALID?  
        is_ovf = rxdata[2] & 2              # TRACE-REG OVERFLOWED?
        is_tbr_valid = rxdata[2] & 4        # TRACE-BUFFER NON-EMPTY?
        is_tbr_full = rxdata[2] & 8         # TRACE-BUFFER FULL?
        is_cpuruns = rxdata[2] & 16         # CPU-RUNNING?
        # print('icd_cpu_read_trace got {}'.format(rxdata.hex()))

        return (is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rxdata[3:])
