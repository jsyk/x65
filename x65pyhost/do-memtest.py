#!/usr/bin/python3
import x65ftdi
from icd import *
import random

icd = ICD(x65ftdi.X65Ftdi())

myseed = random.randint(0, 1024)


# test the RAMBANK and ROMBANK registers
banks = icd.bankregs_read(0, 2)
print('Original Banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))

icd.bankregs_write(0, bytearray([0x12, 0x34]))
newbanks = icd.bankregs_read(0, 2)
print('Testing Banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(newbanks[0], newbanks[1]))

icd.bankregs_write(0, bytearray([0x00, 0x1F]))
newbanks = icd.bankregs_read(0, 2)
print('Default Banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(newbanks[0], newbanks[1]))


# run complete sram memory test
icd.sram_memtest(myseed, 0, ICD.SIZE_2MB)
#icd.sram_memtest(myseed, 0, 10240)

