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

v.vpoke0_setup(0, 1)
for a in range(0, 0x1F9BF):
    # v.vpoke(a, (a >> 4) & 0xFF)
    icd.iopoke(v.DATA0, ((32+a) >> 4) & 0xFF)

print("After Vpoke")
v.vdump_regs()
