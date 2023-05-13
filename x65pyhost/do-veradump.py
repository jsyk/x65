#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *
from vera import *

icd = ICD(x65ftdi.X65Ftdi())
v = VERA(icd)

print("Dump VERA registers")
v.vdump_regs()
