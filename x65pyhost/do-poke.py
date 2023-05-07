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
apa.add_argument('addr')
apa.add_argument('data')

args = apa.parse_args()

addr = int(args.addr, 0)
data = int(args.data, 0)

print("POKE area:{} addr:{:4} data:{:2}".format(args.area, args.addr, args.data))


if args.area == 'sram':
    areasize = ICD.SIZE_2MB
    if addr < 0:
        addr = areasize + addr
    
    icd.sram_blockwrite(addr, [data])

if args.area == 'io':
    areasize = 256
    icd.ioregs_write(addr, [data])
