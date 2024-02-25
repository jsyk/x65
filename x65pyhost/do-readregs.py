#!/usr/bin/python3
import x65ftdi
from icd import *
from cpustate import *
import argparse
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style

colorama_init()

# define connection to the target board via the USB FTDI
icd = ICD(x65ftdi.X65Ftdi())

# which CPU is installed in the target?
is_cputype02 = icd.com.is_cputype02()


cpust = CpuState()
cpust.cpu_read_regs(icd)

banks = icd.bankregs_read(0, 2)
print('Active banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
print('CPU Type (FTDI strap): {}'.format("65C02" if is_cputype02 else "65C816"))

print(cpust)
