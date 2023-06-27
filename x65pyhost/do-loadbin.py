#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

icd = ICD(x65ftdi.X65Ftdi())

apa = argparse.ArgumentParser(usage="%(prog)s [OPTION] file area start",
    description="Load X65 memory."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0"
)

apa.add_argument('file')
apa.add_argument('area')
apa.add_argument('start')

args = apa.parse_args()


banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
rambank = banks[0]
rombank = banks[1]

start = int(args.start, 0)
# length = int(args.length, 0)

print("LOADBIN file:{} -> area:{} addr:0x{:x}".format(args.file, args.area, start))


# f = open('tests65/microhello.bin', 'rb')
f = open(args.file, 'rb')
data = f.read()
print("Loaded {} B from the file.".format(len(data)))

if args.area == 'sram':
    areasize = ICD.SIZE_2MB
    if start < 0:
        start = areasize + start
    icd.sram_blockwrite(start, data)
else:
    print("Only the SRAM area is supported!")

print("Stored to X65.")
