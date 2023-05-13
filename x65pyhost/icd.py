# import x65ftdi
import random

class ICD:
    # Definition of ICD protocol:
    # First byte low nible = command:
    CMD_GETSTATUS =	0x0
    CMD_BUSMEM_ACC = 0x1
    CMD_CPUCTRL = 0x2
    CMD_READTRACE =	0x3

    # First byte high nible = options:
    # ... in case of CMD_BUSMEM_ACC:
    nSRAM_OTHER_BIT =	4
    nWRITE_READ_BIT =	5
    ADR_INC_BIT =		6

    ICD_OTHER_BANKREG_BIT = 19
    ICD_OTHER_IOREG_BIT = 18

    # Composite commands
    ICD_SRAM_WRITE	= (CMD_BUSMEM_ACC | (1 << ADR_INC_BIT))
    ICD_SRAM_READ =	(CMD_BUSMEM_ACC | (1 << nWRITE_READ_BIT) | (1 << ADR_INC_BIT))

    ICD_OTHER_WRITE = (CMD_BUSMEM_ACC | (1 << nSRAM_OTHER_BIT) | (1 << ADR_INC_BIT))
    ICD_OTHER_READ = (CMD_BUSMEM_ACC | (1 << nSRAM_OTHER_BIT) | (1 << nWRITE_READ_BIT) | (1 << ADR_INC_BIT))

    # Aux definitions
    BLOCKSIZE = 256
    PAGESIZE = 8192
    MAXREQSIZE = 16384
    SIZE_2MB =	(2048 * 1024)


    def __init__(self, com):
        # communication link - x65ftdi
        self.com = com


    def busread(self, cmd, maddr, n):
        hdr = bytes( [cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF, 0x00 ] )
        self.com.icd_chip_select()
        rxdata = self.com.spiexchange(hdr, n+len(hdr))
        # slave.write(hdr, start=False, stop=False, droptail=1)
        # rxdata = slave.read(n, start=False, stop=False)
        self.com.icd_chip_deselect()
        return rxdata[5:]

    def buswrite(self, cmd, maddr, data):
        hdr = bytes([cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF ])
        self.com.icd_chip_select()
        self.com.spiwriteonly(hdr)
        self.com.spiwriteonly(data)
        self.com.icd_chip_deselect()


    def bankregs_read(self, maddr, n):
        maddr &= 1
        maddr |= (1 << ICD.ICD_OTHER_BANKREG_BIT)
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    def bankregs_write(self, maddr, data):
        maddr &= 1
        maddr |= (1 << ICD.ICD_OTHER_BANKREG_BIT)
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)


    def ioregs_read(self, maddr, n):
        maddr &= 0xFF
        maddr |= (1 << ICD.ICD_OTHER_IOREG_BIT)
        return self.busread(ICD.ICD_OTHER_READ, maddr, n)

    def ioregs_write(self, maddr, data):
        maddr &= 0xFF
        maddr |= (1 << ICD.ICD_OTHER_IOREG_BIT)
        return self.buswrite(ICD.ICD_OTHER_WRITE, maddr, data)

    def iopoke(self, addr, data):
        return self.ioregs_write(addr, [data])


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
                print("  Writing page 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
                        int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE), int((b+1) + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE - 1))
            
            self.sram_blockwrite(mstart + b * ICD.BLOCKSIZE, buf);
        
        # restart rand sequence
        random.seed(seed)
        
        errors = 0

        for b in range(0, blocks):
            if ((b * ICD.BLOCKSIZE) % ICD.PAGESIZE == 0):
                print("  Reading page 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
                        int(b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE, int((b+1) + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE - 1))
            
            buf1 = self.sram_blockread(mstart + b * ICD.BLOCKSIZE, ICD.BLOCKSIZE)
            buf2 = random.randbytes(ICD.BLOCKSIZE)
            # print('buf1={}'.format(buf1.hex()))
            # print('buf2={}'.format(buf2.hex()))
            if buf1 != buf2:
                errors += 1
                print("  Error in page 0x{:x} (0x{:x} to 0x{:x})!".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
                            mstart + b*ICD.BLOCKSIZE, mstart + (b-1)*ICD.BLOCKSIZE - 1))

        print("Memtest done with {} errors.".format(errors))
        return errors


    def cpu_ctrl(self, run_cpu, cstep_cpu, reset_cpu):
        run_cpu = 1 if run_cpu else 0
        cstep_cpu = 1 if cstep_cpu else 0
        reset_cpu = 1 if reset_cpu else 0

        hdr = bytes([ ICD.CMD_CPUCTRL | (run_cpu << 4) | (cstep_cpu << 5), reset_cpu ])

        self.com.icd_chip_select()
        self.com.spiwriteonly(hdr)
        self.com.icd_chip_deselect()


    def cpu_read_trace(self, tbuflen):
        #                        /*dummy*/
        hdr = bytes([ ICD.CMD_READTRACE, 0  ])

        self.com.icd_chip_select();
        rxdata = self.com.spiexchange(hdr, tbuflen+1+len(hdr))
        self.com.icd_chip_deselect()

        is_valid = rxdata[2] & 1
        is_ovf = rxdata[2] & 2
        # print('icd_cpu_read_trace got {}'.format(rxdata.hex()))

        return (is_valid, is_ovf, rxdata[3:])
