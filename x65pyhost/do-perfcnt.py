#!/usr/bin/python3
import x65ftdi
from icd import *
import argparse
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style
import random

colorama_init()

# define connection to the target board via the USB FTDI
icd = ICD(x65ftdi.X65Ftdi(log_file_name='spi-log.txt'))

# which CPU is installed in the target?
is_cputype02 = icd.com.is_cputype02()


CMD_READ_SS_PERFCNT = 0x7


def ssperf_clear():
    hdr = bytes([ CMD_READ_SS_PERFCNT | (1 << 5), 0  ])

    icd.com.icd_chip_select();
    rxdata = icd.com.spiexchange(hdr, len(hdr))
    icd.com.icd_chip_deselect()

def ssperf_run(run=True):
    run = 1 if run else 0

    hdr = bytes([ CMD_READ_SS_PERFCNT | (run << 4), 0  ])

    icd.com.icd_chip_select();
    rxdata = icd.com.spiexchange(hdr, len(hdr))
    icd.com.icd_chip_deselect()

def ssperf_readout():
    hdr = bytes([ CMD_READ_SS_PERFCNT, 0, 0  ])

    icd.com.icd_chip_select();
    rxdata = icd.com.spiexchange(hdr, len(hdr) + 64)
    icd.com.icd_chip_deselect()
    return rxdata


print("Performance counters")

ssperf_clear()
ssperf_run(True)

for i in range(0, 50):
    # rdata = icd.bankregs_read(0, 2)
    hdr = bytearray([ CMD_READ_SS_PERFCNT | (1 << 4), 0, 0  ])
    hdr.extend(random.randbytes(100))

    icd.com.icd_chip_select();
    rxdata = icd.com.spiexchange(hdr, len(hdr))
    icd.com.icd_chip_deselect()

# print("banks = {}".format(rdata))

ssperf_run(False)

#  perf= 12 12 00 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 34 12 
perf = ssperf_readout()
perf = perf[3:]

# print(perf)
print(' perf=0x.. {}\n'.format( ''.join('{:02x} '.format(x) for x in perf) ))

for i in range(0, 32):
    v = perf[2*i] + perf[2*i + 1] * 256
    print(" {}".format(v))
