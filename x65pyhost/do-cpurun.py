#!/usr/bin/python3
import x65ftdi
from icd import *

icd = ICD(x65ftdi.X65Ftdi())




print("CPU Run:\n")
# // deactivate the reset, step the cpu
icd.cpu_ctrl(True, False, False)
