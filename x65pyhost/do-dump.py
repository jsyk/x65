#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

icd = ICD(x65ftdi.X65Ftdi())


apa = argparse.ArgumentParser(usage="%(prog)s [OPTION] area start length",
    description="Dump X65 memory."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0"
)

apa.add_argument('area')
apa.add_argument('start')
apa.add_argument('length')

args = apa.parse_args()

# print(args.area)
# print(args.start)
# print(args.length)


# start = 0xFF00
# length = 256
# start = 256*8192 - length
# start = 0x170100          # stack area


banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
rambank = banks[0]
rombank = banks[1]

start = int(args.start, 0)
length = int(args.length, 0)

print("DUMP area:{} addr:0x{:x} length:{:2}".format(args.area, start, length))


if args.area == 'sram':
    areasize = ICD.SIZE_2MB
    if start < 0:
        start = areasize + start
    
    rdata = icd.sram_blockread(start, length)

if args.area == 'io':
    areasize = 256
    rdata = icd.ioregs_read(start, length)

if args.area == 'banks':
    areasize = 2
    rdata = icd.bankregs_read(start, length)

if args.area == 'cpu':
    areasize = 65536
    if start < 0:
        start = areasize + start

    # TODO: this code doesn't handle the crossing of boundary within a single dump!!
    if 0 <= start < 2:
        # bank regs
        rdata = icd.bankregs_read(start, length)
    elif start < 0x9F00:
        # CPU low memory starts at sram fix 0x170000
        rdata = icd.sram_blockread(start + 0x170000, length)
    elif 0xA000 <= start < 0xC000:
        # CPU RAM Bank starts at sram fix 0x000
        rdata = icd.sram_blockread((start - 0xA000) + rambank*ICD.PAGESIZE, length)
    elif 0xC000 <= start:
        # CPU ROM bank starts at sram fix 0x180000
        rdata = icd.sram_blockread((start - 0xC000) + 0x180000 + rombank*2*ICD.PAGESIZE, length)


BYTESSPERLINE = 16
print()

print("             +0 +1 +2 +3   +4 +5 +6 +7   +8 +9 +A +B   +C +D +E +F")

k = 0
while k < length:
    # start of line: print memory address
    print(' {:6x}:  '.format(start+k), end='')

    # print dump block in hex
    for i in range(0, BYTESSPERLINE):
        if (i % 4) == 0:
            print('  ', end='')
        
        if (k+i < length):
            # print hex data value
            print(' {:02x}'.format(rdata[k+i]), end='')
        else:
            # out of range, print white space till end of hex block
            print('   ', end='')

    print('     ', end='')

    # print dump block in ascii character
    for i in range(0, BYTESSPERLINE):
        if (k+i < length):
            # print ascii data value
            c = rdata[k+i]
            print('{}'.format(chr(c) if 32 <= c < 128 else '?'), end='')
        else:
            # out of range, print white space till end of hex block
            print('   ', end='')

    k += BYTESSPERLINE
    print()

print()
