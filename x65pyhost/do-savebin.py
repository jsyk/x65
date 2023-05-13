#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

icd = ICD(x65ftdi.X65Ftdi())

apa = argparse.ArgumentParser(usage="%(prog)s [OPTION] area start length",
    description="Save X65 memory."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0"
)

apa.add_argument('file')
apa.add_argument('area')
apa.add_argument('start')
apa.add_argument('length')

args = apa.parse_args()


banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
rambank = banks[0]
rombank = banks[1]

start = int(args.start, 0)
length = int(args.length, 0)

print("SAVEBIN file:{} <- area:{} addr:0x{:x} length:{}".format(args.file, args.area, start, length))


# f = open('tests65/microhello.bin', 'rb')
f = open(args.file, 'wb')

if args.area == 'sram':
    areasize = ICD.SIZE_2MB
    if start < 0:
        start = areasize + start
    data = icd.sram_blockread(start, length)
else:
    print("Only the SRAM area is supported!")

f.write(data)
print("Saved {} B to the file.".format(len(data)))
