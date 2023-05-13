#!/usr/bin/python3
import x65ftdi
from icd import *

icd = ICD(x65ftdi.X65Ftdi())


banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))


print("CPU Run:\n")
# // deactivate the reset, step the cpu
icd.cpu_ctrl(True, False, False)
