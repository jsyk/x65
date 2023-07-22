#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *
from vera import *

icd = ICD(x65ftdi.X65Ftdi())
v = VERA(icd)

# DCSEL=0, ADRSEL=0
icd.iopoke(v.CTRL, 0x00)
# Enable output to VGA, enable Layer0
icd.iopoke(v.DC_VIDEO, v.OUTMODE_VGA | v.LAYER0_ENABLE)

# Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
icd.iopoke(v.L0_CONFIG, (v.MAP_WH_128T << 6) | (v.MAP_WH_128T << 4) | VERA.BPP_1)
# map entries start at address 0 of VRAM, and occupy 32kB
icd.iopoke(v.L0_MAPBASE, 0x00)
# tile (font) starts at 32kB offset
tilebase_va = 0x8000           # v-addr 32768
# TileBase starts at 32kB offset. Each tile is 8x8 pixels
icd.iopoke(v.L0_TILEBASE, ((tilebase_va >> 11) << 2))

# write font data to the tile memory
v.vpoke0_setup(tilebase_va, 1)
# 8 bytes (64 bits) per character
nanofont = [ 0, 0, 0, 0,  0, 0, 0, 0, 
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
for a in range(0, 16):
    icd.iopoke(v.DATA0, nanofont[a])


# write character/color data in the map:
# a tile map containing tile map entries, which are 2 bytes each:
# Offset 	Bit 7 	Bit 6 	Bit 5 	Bit 4 	Bit 3 	Bit 2 	Bit 1 	Bit 0
# 0 	    Character index
# 1 	    Background color 	            Foreground color
# v.vpoke0_setup(0, 1)
c = 0
for y in range(0, 60):
    for x in range(0, 80):
        # 
        ci = 2*x + 2*128*y
        v.vpoke(ci, c)              # character
        v.vpoke(ci+1, x+y)            # colors
        c = (c + 1) & 0x1
        # icd.iopoke(v.DATA0, (((a >> 1)+32) & 0xFF))
        # icd.iopoke(v.DATA0, ((32+a) >> 4) & 0xFF)

art = """
012345670123456701234567
X     X   XXXX   XXXXX
 X   X   X       X
  X X    X       X
   X     XXXXX   XXXXX
  X X    X    X       X
 X   X   X    X  X    X
X     X   XXXX    XXXX
.
         XXXXX   X    X
         X       X    X
         X       X    X
         XXXXX   X    X
         X       X    X
  XX     X       X    X
  XX     XXXXX    XXXX
.
"""



print("After Vpoke")
v.vdump_regs()
