#!/usr/bin/python3
import x65ftdi
from icd import *

icd = ICD(x65ftdi.X65Ftdi())

# // stop cpu, activate the reset
print("CPU Stop & Reset")
icd.cpu_ctrl(False, False, True)
# read_print_trace()
# read_print_trace()

print("CPU Step while in Reset")
# // step the cpu while reset is active for some time
for i in  range(0, 10):
    icd.cpu_ctrl(False, True, True)
    # read_print_trace()

banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
