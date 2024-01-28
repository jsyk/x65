#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

apa = argparse.ArgumentParser(usage="%(prog)s [OPTION]",
    description="Reset the CPU."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0")
apa.add_argument(
    "-r", "--rombank", action="store", type=lambda x: int(x, 0))
apa.add_argument(
    "-R", "--run", action="store_true")

args = apa.parse_args()


icd = ICD(x65ftdi.X65Ftdi())

# // stop cpu, activate the reset
print("CPU Stop & Reset")
icd.cpu_ctrl(False, False, True)
# read_print_trace()
# read_print_trace()

if args.rombank is not None:
    print('Set ROMBANK to 0x{:x}'.format(args.rombank))
    icd.bankregs_write(1, [args.rombank])

print("CPU Step while in Reset")
# // step the cpu while reset is active for some time
for i in  range(0, 10):
    icd.cpu_ctrl(False, True, True)
    # read_print_trace()

banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))

if args.run:
    print("CPU Run!\n")
    # // deactivate the reset, step the cpu
    icd.cpu_ctrl(True, False, False)
