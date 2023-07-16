#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

icd = ICD(x65ftdi.X65Ftdi())

apa = argparse.ArgumentParser(usage="%(prog)s [OPTION] file.prg",
    description="Load X65 memory from a PRG file (first two bytes define the start address, typically 0x0801)."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0"
)

apa.add_argument('file')

args = apa.parse_args()


banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
rambank = banks[0]
rombank = banks[1]

# start = int(args.start, 0)
# length = int(args.length, 0)

# print("LOADBIN file:{} -> area:{} addr:0x{:x}".format(args.file, args.area, start))


# f = open('tests65/microhello.bin', 'rb')
f = open(args.file, 'rb')
start = int.from_bytes(f.read(2), 'little')
print("Start address in the PRG file is 0x{:x}".format(start))
data = f.read()
print("Loaded {} B of data from the file.".format(len(data)))

# SRAM area always

areasize = ICD.SIZE_2MB
if start < 0:
    start = areasize + start
icd.sram_blockwrite(start, data)

print("Stored to X65.")
