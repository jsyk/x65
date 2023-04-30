#!/usr/bin/python3
import x65ftdi
from icd import *

icd = ICD(x65ftdi.X65Ftdi())

area = 'sram'
# start = 0xFF00
length = 16384
start = 256*8192 - length
# start = 0x170100


# f = open('tests65/microhello.bin', 'rb')
f = open('tests65/blink.bin', 'rb')
data = f.read(length)
icd.sram_blockwrite(start, data)
