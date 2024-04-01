# import x65ftdi
import random

# ICD - In-Circuit Debugger
# This class provides the low-level access to the ICD (In-Circuit Debugger) of the X65.
# The ICD is a part of the NORA (NORmalized Architecture) of the X65, and it is used to
# access the CPU, SRAM, IO registers, and other parts of the X65.
# The ICD is accessed via the USB interface of the X65, which is converted by FTDI chip to SPI.
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
    PG65SIZE = 256             # misnomer => PAGE
    BLOCKSIZE = 8192             # misnomer => BLOCK
    MAXREQSIZE = 16384          # max size of a single request (FTDI limit)
    SIZE_2MB =	(2048 * 1024)

    # CPU Status flags (low byte of tr_flag)
    TRACE_FLAG_RWN =		1
    TRACE_FLAG_EF =         2
    TRACE_FLAG_VDA =        4
    TRACE_FLAG_VECTPULL =	8
    TRACE_FLAG_MLOCK =		16
    TRACE_FLAG_SYNC_VPA =   32
    TRACE_FLAG_CSOB_M =     64
    TRACE_FLAG_RDY =        128
    # CPU Control flag (high byte of tr_flag)
    TRACE_FLAG_CSOB_X =     16 << 8     # status
    TRACE_FLAG_RESETN =     8 << 8
    TRACE_FLAG_IRQN =       4 << 8
    TRACE_FLAG_NMIN =       2 << 8
    TRACE_FLAG_ABORTN =     1 << 8

    # Composite flag: ISYNC = start of an instruction (first CPU cycle)
    TRACE_FLAG_ISYNC = TRACE_FLAG_VDA | TRACE_FLAG_SYNC_VPA            # both must be set to indicate first byte of an instruction

    def __init__(self, com):
        # communication link - x65ftdi
        self.com = com
        self.is_cputype02_hw = None

    # return true iff the CPU is 65C02, and false iff it is 65C816.
    # The result is cached, and the CPU type is read from the hw only once.
    def is_cputype02(self) -> bool:
        # cached?
        if self.is_cputype02_hw is None:
            # no -> read from the hw!
            self.is_cputype02_hw = self.com.is_cputype02()
        return self.is_cputype02_hw

    # Read bytes from X65 bus. This is a primitive base function used in below methods.
    # cmd: command byte, one of ICD.CMD_*
    # maddr: 24-bit bus address
    # n: number of bytes to read
    def busread(self, cmd, maddr, n):
        hdr = bytes( [cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF, 0x00 ] )
        self.com.icd_chip_select()
        rxdata = self.com.spiexchange(hdr, n+len(hdr))
        # slave.write(hdr, start=False, stop=False, droptail=1)
        # rxdata = slave.read(n, start=False, stop=False)
        self.com.icd_chip_deselect()
        return rxdata[5:]

    # Write data bytes to X65 bus. This is a primitive base function used in below methods.
    # cmd: command byte, one of ICD.CMD_*
    # maddr: 24-bit bus address
    # data: bytes to write
    def buswrite(self, cmd, maddr, data):
        hdr = bytes([cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF ])
        self.com.icd_chip_select()
        self.com.spiwriteonly(hdr)
        self.com.spiwriteonly(data)
        self.com.icd_chip_deselect()


    # Read from BLOCKREGs area.
    # maddr: 0 or 1, corresponding to RAMBLOCK_REG and ROMBLOCK_REG
    # n: number of bytes to read (practically just 1 or 2 is allowed)
    def bankregs_read(self, maddr, n):
        # BLOCKREGs area is just 2Bytes wide, so the maddr is just 1 bit
        maddr &= 1
        maddr |= (1 << ICD.ICD_OTHER_BANKREG_BIT)
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    # Write to BLOCKREGs
    # maddr: 0 or 1, corresponding to RAMBLOCK_REG and ROMBLOCK_REG
    # data: bytes to write (practically just 1 or 2 is allowed)
    def bankregs_write(self, maddr, data):
        # BLOCKREGs area is just 2Bytes wide, so the maddr is just 1 bit
        maddr &= 1
        maddr |= (1 << ICD.ICD_OTHER_BANKREG_BIT)
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)

    # Read bytes from IO registers.
    # maddr: 8-bit address of the IO register
    # n: number of bytes to read, max 256
    def ioregs_read(self, maddr, n):
        # IOREGs area is just 256Bytes wide, so the maddr is just 8 bits
        maddr &= 0xFF
        # The 0x9F helps NORA to position Scratchpad area in SRAM for the ICD access
        maddr |= (1 << ICD.ICD_OTHER_IOREG_BIT) | 0x9F00
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    # Write bytes to IO registers.
    # The IO area is located in the CPU address space at 0x9F00-0x9FFF, but here
    # it is accessed via the ICD as a separate area, thus it as the base address 0x0000.
    # maddr: 8-bit address of the IO register
    # data: bytes to write
    def ioregs_write(self, maddr, data):
        # IOREGs area is just 256Bytes wide, so the maddr is just 8 bits
        maddr &= 0xFF
        # The 0x9F helps NORA to position Scratchpad area in SRAM for the ICD access,
        # but it is not necessary otherwise.
        maddr |= (1 << ICD.ICD_OTHER_IOREG_BIT) | 0x9F00
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)

    # Write 1byte to IO register. Helper function.
    # The IO area is located in the CPU address space at 0x9F00-0x9FFF, but here
    # it is accessed via the ICD as a separate area, thus it as the base address 0x0000.
    # addr: 8-bit address of the IO register
    # data: 1 byte to write
    def iopoke(self, addr, data):
        return self.ioregs_write(addr, [data])

    # read 1byte from IO register. Helper function.
    # addr: 8-bit address of the IO register
    def iopeek(self, addr):
        data = self.ioregs_read(addr, 1)
        return data[0]

    # Read from the bootrom area used by the PBL (Primary Boot Loader).
    # maddr: 12-bit offset in the bootrom
    # n: number of bytes to read
    def bootrom_blockread(self, maddr, n):
        # Bootrom area is just 4kB wide, so the maddr is just 12 bits
        maddr &= 0xFFF
        maddr |= (1 << ICD.ICD_OTHER_BOOTROM_BIT)
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    # Write the bootrom area used by the PBL (Primary Boot Loader).
    # maddr: 12-bit offset in the bootrom
    # data: bytes to write
    def bootrom_blockwrite(self, maddr, data):
        # Bootrom area is just 4kB wide, so the maddr is just 12 bits
        maddr &= 0xFFF
        maddr |= (1 << ICD.ICD_OTHER_BOOTROM_BIT)
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)

    # Write bytes to SRAM.
    # maddr: 24-bit address in the SRAM
    # data: bytes to write
    def sram_blockwrite(self, maddr, data):
        k = 0
        # write in chunks of MAXREQSIZE (FTDI limit)
        while len(data)-k > ICD.MAXREQSIZE:
            self.buswrite(ICD.ICD_SRAM_WRITE, maddr+k, data[k:k+ICD.MAXREQSIZE])
            k = k + ICD.MAXREQSIZE
        # write the rest
        self.buswrite(ICD.ICD_SRAM_WRITE, maddr+k, data[k:])

    # Read bytes from SRAM.
    # maddr: 24-bit address in the SRAM
    # n: number of bytes to read
    def sram_blockread(self, maddr, n):
        # FIXME: read in chunks of MAXREQSIZE (FTDI limit) - is this necessary?
        return self.busread(ICD.ICD_SRAM_READ, maddr, n)

    # Run memory test on the SRAM. Destroys the content of the SRAM.
    # seed: random seed for the test
    # mstart: start address of the test
    # mbytes: number of bytes to test; should be a multiple of PG65SIZE (256Bytes)
    def sram_memtest(self, seed, mstart, mbytes):
        # uint8_t buf[PG65SIZE];
        # calculate the number of blocks
        blocks = int(mbytes / ICD.PG65SIZE)

        print("SRAM Memtest from 0x{:x} to 0x{:x}, rand seed 0x{:x}".format(
                mstart, mstart + mbytes - 1, seed));

        # restart rand sequence
        random.seed(seed)

        # write the tested memory with a pseudo-random sequence
        for b in range(0, blocks):
            # generate a random block
            buf = random.randbytes(ICD.PG65SIZE)
            # print message for each page
            if ((b * ICD.PG65SIZE) % ICD.BLOCKSIZE == 0):
                print("  Writing block 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.PG65SIZE) * ICD.PG65SIZE / ICD.BLOCKSIZE),
                        int((b + mstart/ICD.PG65SIZE) * ICD.PG65SIZE), int((b+1) + mstart/ICD.PG65SIZE) * ICD.PG65SIZE - 1))
            # write to the X65 SRAM
            self.sram_blockwrite(mstart + b * ICD.PG65SIZE, buf);
        
        # restart rand sequence to get the same sequence for verification
        random.seed(seed)
        
        errors = 0          # count the errors

        for b in range(0, blocks):
            if ((b * ICD.PG65SIZE) % ICD.BLOCKSIZE == 0):
                print("  Reading block 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.PG65SIZE) * ICD.PG65SIZE / ICD.BLOCKSIZE),
                        int(b + mstart/ICD.PG65SIZE) * ICD.PG65SIZE, int((b+1) + mstart/ICD.PG65SIZE) * ICD.PG65SIZE - 1))
            # read from X65 SRAM
            buf1 = self.sram_blockread(mstart + b * ICD.PG65SIZE, ICD.PG65SIZE)
            # generate the same random block
            buf2 = random.randbytes(ICD.PG65SIZE)
            # compare the read and generated blocks
            if buf1 != buf2:
                # there is an error :-(
                errors += 1
                print("  Error in block 0x{:x} (0x{:x} to 0x{:x})!".format(int((b + mstart/ICD.PG65SIZE) * ICD.PG65SIZE / ICD.BLOCKSIZE),
                            mstart + b*ICD.PG65SIZE, mstart + (b-1)*ICD.PG65SIZE - 1))

        # summary:
        print("Memtest done with {} errors.".format(errors))
        return errors


    # Decode the MAH (Memory Address High) register from the trace data
    # into the ROMBLOCK and RAMBLOCK numbers - depending also on the captured CBA and CA.
    # Note that not all fields are valid for all combinations of CBA and CA.
    # Alternatively, the ROMBLOCK and RAMBLOCK could be read from the HW via the ICD link,
    # but this is not always possible  (e.g. when the CPU is running) or suitable (e.g. in mid-trace,
    # since the present HW state could be different from the historic trace data).
    class MAHDecoded:
        # This __init__ method is private and should not be called directly.
        # Use from_trace() or from_hw() instead.
        def __init__(self):
            self.sram_block_raw = None
            self.has_bootrom = None         # None because we don't know!
        
        @classmethod
        def from_trace(cls, MAH, CBA, CA):
            # create MAHDecoded object
            self = cls()
            # For CBA == 0, the CA is in the ROM, RAM, or IO area.
            if CBA == 0:
                # bank zero -> must decode carefuly
                # if 0 <= CA < 2:
                #     # bank regs
                #     # self.romblock = None
                #     # self.ramblock_raw = None
                #     pass        # TBD: what here? Nora should give us a hint if these are BLOCKREGS !!!
                # el
                if CA < 0x9F00:
                    # CPU low memory starts at sram fix 0x000000
                    self.sram_block_raw = 0x00      # low-memory starts in SRAM block 0
                elif 0xA000 <= CA < 0xC000:
                    # CPU RAM-Block from $A000 to $BFFF
                    self.sram_block_raw = MAH
                elif 0xC000 <= CA < 0xE000:
                    # CPU second RAM-Block from $C000 to $DFFF,
                    # or ROM-Block
                    # or direct mapped memory.
                    # -> In any case, the decoded SRAM Block is in MAH already.
                    self.sram_block_raw = MAH
                elif 0xE000 <= CA:
                    # CPU ROM bank,
                    # or direct mapped memory.
                    # -> In any case, the decoded SRAM Block is in MAH already.
                    self.sram_block_raw = MAH & 0x7F            # ROM-Block could not located in upper half of SRAM, by design!
                    self.has_bootrom = (MAH & 0x80) != 0        # MAH msb indicates if it is bootroom; True or False
            else:
                # CPU Bank non-zero -> linear address into SRAM
                self.sram_block_raw = MAH
                self.has_bootrom = None         # None because we don't know!
            return self

        @classmethod
        def from_hw(cls, icd, CBA, CA):
            # create MAHDecoded object
            self = cls()
            # read current ROMBLOCK and RAMBLOCK registers from the hw via the icd link
            bregs = icd.ioregs_read(0x50, 2)
            # read RMBCTRL reg at 0x9F53
            rmbctrl = icd.iopeek(0x53)
            self.has_bootrom = (rmbctrl & 0x80) != 0
            ENABLE_ROM_CDEF = (rmbctrl & 0x10) != 0
            ENABLE_RAM_CD = (rmbctrl & 0x08) != 0

            if CBA == 0:
                if CA < 0x9F00:
                    # CPU low memory starts at sram fix 0x000000
                    self.sram_block_raw = 0x00      # low-memory starts in SRAM block 0
                elif 0xA000 <= CA < 0xC000:
                    # CPU RAM-Block from $A000 to $BFFF
                    ramblock_raw = bregs[0] ^ 0x80
                    self.sram_block_raw = ramblock_raw
                elif 0xC000 <= CA < 0xE000:
                    # CPU second RAM-Block from $C000 to $DFFF,
                    # or ROM-Block (lower 8kB)
                    # or direct mapped memory.
                    if ENABLE_ROM_CDEF:
                        # ROM-Block
                        romblock = bregs[1] 
                        self.sram_block_raw = (0x080000 + romblock*2*ICD.BLOCKSIZE) >> 13
                    elif ENABLE_RAM_CD:
                        # the second RAM-Block
                        ramblock2_raw = bregs[1] ^ 0x80
                        self.sram_block_raw = ramblock2_raw
                    else:
                        # nothing of that -> direct underlaying memory
                        self.sram_block_raw = (0xc000 // 8192)       # = 6
                elif 0xE000 <= CA:
                    # CPU ROM bank (upper 8kB),
                    # or direct mapped memory.
                    if ENABLE_ROM_CDEF:
                        # CPU ROM bank (upper 8kB),
                        romblock = bregs[1] 
                        self.sram_block_raw = (0x080000 + (romblock*2 + 1)*ICD.BLOCKSIZE) >> 13
                    else:
                        # direct underlaying memory
                        self.sram_block_raw = (0xe000 // 8192)       # = 7
            else:
                # CBA > 0 ==> no decode:
                self.sram_block_raw = (CBA << 3) + ((CA >> 13) & 0x07)
            return self
        
    # Read a byte via ICD memory access from the target, the way a CPU would do.
    # The address is identified by captured CBA (CPU Bank Address [7:0]), MAH (Memory High Address = SRAM 8kb BLOCK, [20:13]) 
    # and CA (CPU Address [15:0]).
    # MAH is decoded into the bank address.
    def read_byte_as_cpu(self, CBA: int, mahd: MAHDecoded, CA: int) -> int:
        # We have to differentiate based on the CPU Bank Address (65C816 topmost 8 bits of the address).
        # In case of CBA = 0, we must decode the address carefully, because it could be in the ROM, RAM, or IO area.
        # In case of CBA != 0, the address is linear into the SRAM and can be read directly.
        if CBA == 0:
            # bank zero -> must decode carefuly!
            bregs = self.ioregs_read(0x50, 2)
            rmbctrl = self.iopeek(0x53)
            MIRROR_ZP = (rmbctrl & 0x20) != 0
            # ENABLE_ROM_CDEF = (rmbctrl & 0x10) != 0
            # ENABLE_RAM_CD = (rmbctrl & 0x08) != 0

            if (0 <= CA < 2) and MIRROR_ZP:
                # bank regs (mirror to zero page is enabled)
                rdata = bregs[CA]
            elif CA < 0x9F00:
                # CPU low memory starts at sram fix 0x000000
                rdata = self.sram_blockread(CA + 0x000000, 1)
            elif 0xA000 <= CA < 0xC000:
                # CPU RAM Bank between $A000 to $BFFF
                offs = (CA - 0xA000)
                rdata = self.sram_blockread(offs + mahd.sram_block_raw*ICD.BLOCKSIZE, 1)
            elif 0xC000 <= CA < 0xE000:
                # CPU second RAM-Block from $C000 to $DFFF,
                # or ROM-Block (lower 8kB)
                # or direct mapped memory.
                offs = (CA - 0xC000)
                rdata = self.sram_blockread(offs + mahd.sram_block_raw*ICD.BLOCKSIZE, 1)
            elif 0xE000 <= CA:
                # CPU ROM bank (upper 8kB),
                # or direct mapped memory.
                offs = (CA - 0xE000)
                if not mahd.has_bootrom:
                    rdata = self.sram_blockread(offs + mahd.sram_block_raw*ICD.BLOCKSIZE, 1)
                else:
                    # bootrom inside of NORA
                    # print("[bootrom_blockread({})]".format(offs))
                    rdata = self.bootrom_blockread(offs, 1)
        else:
            # CPU Bank non-zero -> linear address into SRAM
            # Form linear address from CBA (highest 8 bits) and CA (lower 16 bits).
            # Since we have just 2 MB or RAM, mask out the remaining bits.
            lin_addr = ((CBA << 16) | CA) & 0x1FFFFF
            rdata = self.sram_blockread(lin_addr, 1)
        return rdata[0]


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
    def cpu_get_status(self):
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
        hdr = bytes([ ICD.CMD_GETSTATUS, 0  ])

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


    # Trace Register
    # with decoder from the raw buffer
    class TraceReg:
        # Decode trace-reg raw buffer received by cpu_read_trace()
        def __init__(self, rawbuf):
            # rawbuf must be (at least) 7 elements
            while len(rawbuf) < 7:
                rawbuf.append(0)
            
            # extract the basic fields from the raw buffer
            self.sta_flags = rawbuf[0]
            self.ctr_flags = rawbuf[1]
            self.CBA = rawbuf[6]           # CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
            self.MAH = rawbuf[5]           # Memory Address High = SRAM Page
            self.CA = rawbuf[4] * 256 + rawbuf[3]        # CPU Address, 16-bit
            self.CD = rawbuf[2]                # CPU Data

            # tr_flag is a combination of status and ctrl flags
            self.tr_flag = self.sta_flags + (self.ctr_flags << 8)

            # extract individual flags from the status and control fields
            self.is_sync = (self.tr_flag & ICD.TRACE_FLAG_ISYNC) == ICD.TRACE_FLAG_ISYNC
            self.is_resetn = ((self.tr_flag & ICD.TRACE_FLAG_RESETN) == ICD.TRACE_FLAG_RESETN)
            self.is_irqn = ((self.tr_flag & ICD.TRACE_FLAG_IRQN) == ICD.TRACE_FLAG_IRQN)
            self.is_nmin = ((self.tr_flag & ICD.TRACE_FLAG_NMIN) == ICD.TRACE_FLAG_NMIN)
            self.is_abortn = ((self.tr_flag & ICD.TRACE_FLAG_ABORTN) == ICD.TRACE_FLAG_ABORTN)
            self.is_read_nwrite = ((self.tr_flag & ICD.TRACE_FLAG_RWN) == ICD.TRACE_FLAG_RWN)
            self.is_emu8 = (self.tr_flag & ICD.TRACE_FLAG_EF) == ICD.TRACE_FLAG_EF
            self.is_nat16 = not self.is_emu8
            self.is_vda = (self.tr_flag & ICD.TRACE_FLAG_VDA) == ICD.TRACE_FLAG_VDA
            self.is_vectpull = (self.tr_flag & ICD.TRACE_FLAG_VECTPULL) == ICD.TRACE_FLAG_VECTPULL
            self.is_mlock = (self.tr_flag & ICD.TRACE_FLAG_MLOCK) == ICD.TRACE_FLAG_MLOCK
            self.is_vpa = (self.tr_flag & ICD.TRACE_FLAG_SYNC_VPA) == ICD.TRACE_FLAG_SYNC_VPA
            self.is_am8 = ((self.tr_flag & ICD.TRACE_FLAG_CSOB_M) == ICD.TRACE_FLAG_CSOB_M)  
            self.is_xy8 = ((self.tr_flag & ICD.TRACE_FLAG_CSOB_X)  == ICD.TRACE_FLAG_CSOB_X)
            self.is_rdy = (self.tr_flag & ICD.TRACE_FLAG_RDY) == ICD.TRACE_FLAG_RDY

