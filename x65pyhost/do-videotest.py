#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *
from vera import *

icd = ICD(x65ftdi.X65Ftdi())
v = VERA(icd)


# def iopoke(addr, data):
#     icd.ioregs_write(addr, [data])

# Enable output to VGA
icd.iopoke(v.CTRL, 0x00)
icd.iopoke(v.DC_VIDEO, v.OUTMODE_VGA | v.LAYER0_ENABLE)

icd.iopoke(v.CTRL, 0x00)
print("Dump with DCSEL=0, ADDRSEL=0")
v.vdump_regs()

print("Dump with DCSEL=1, ADDRSEL=0")
icd.iopoke(v.CTRL, v.DC_SEL)
v.vdump_regs()

icd.iopoke(v.CTRL, 0x00)
icd.iopoke(v.L0_CONFIG, VERA.BITMAP_MODE | 3)

# # prepare DATA0 reg: start addr = 0, increment on every access
# v.vpoke0_setup(0, 1)

# for a in range(0, 0x1F9BF):
#     # v.vpoke(a, (a >> 4) & 0xFF)
#     icd.iopoke(v.DATA0, ((32+a) >> 4) & 0xFF)

# print("After Vpoke")
# v.vdump_regs()


myseed = random.randint(0, 1024)
test_vram_end = 0x1F9BF
# note: on a just-started OpenX65, the memtest with above parameters passed!

# test_vram_end = 0x1F000

print("VRAM MEMTEST: seed={}, end=0x{:x}".format(myseed, test_vram_end))

# ###############################################################3
print('Writing pseudo-random data byte to VRAM...')

# restart rand sequence
random.seed(myseed)

# prepare DATA0 reg: start addr = 0, increment on every access
v.vpoke0_setup(0, inc=True)

for b in range(0, test_vram_end):
    byte = random.randrange(0, 256)
    # if ((b * ICD.BLOCKSIZE) % ICD.PAGESIZE == 0):
    #     print("  Writing page 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
    #             int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE), int((b+1) + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE - 1))
    icd.iopoke(v.DATA0, byte & 0xFF)

# ###############################################################3
print('Checking pseudo-random data bytes in VRAM...')

# restart rand sequence
random.seed(myseed)

errors = 0

# prepare DATA0 reg: start addr = 0, increment on every access
v.vpoke0_setup(0, inc=True)

for b in range(0, test_vram_end):
    byte1 = icd.iopeek(v.DATA0)
    byte2 = random.randrange(0, 256)

    # if ((b * ICD.BLOCKSIZE) % ICD.PAGESIZE == 0):
    #     print("  Reading page 0x{:x} (0x{:x} to 0x{:x})...".format(int((b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE / ICD.PAGESIZE),
    #             int(b + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE, int((b+1) + mstart/ICD.BLOCKSIZE) * ICD.BLOCKSIZE - 1))
    
    # buf1 = self.sram_blockread(mstart + b * ICD.BLOCKSIZE, ICD.BLOCKSIZE)
    # buf2 = random.randbytes(ICD.BLOCKSIZE)
    # print('buf1={}'.format(buf1.hex()))
    # print('buf2={}'.format(buf2.hex()))
    if byte1 != byte2:
        errors += 1
        print("  Error at VRAM address 0x{:x}: expected=0x{:x}, real=0x{:x}".format(b, byte2, byte1))
    if errors > 100:
        print("Too many errors, canceling.")
        break

print("Memtest done with {} errors.".format(errors))
