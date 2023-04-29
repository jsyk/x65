#!/usr/bin/python3
import x65ftdi
from icd import *

icd = ICD(x65ftdi.X65Ftdi())

area = 'sram'
# start = 0xFF00
length = 256
start = 256*8192 - length
# start = 0x170100          # stack area


banks = icd.bankregs_read(0, 2)
print('Banks: RAMBANK={:2x}  ROMBANK={:2x}'.format(banks[0], banks[1]))
# banks = icd.bankregs_read(1, 1)
# print('Banks: ROMBANK={:2x}'.format(banks[0]))


rdata = icd.sram_blockread(start, length)

BYTESSPERLINE = 16
print()

k = 0
while k < length:
    # start of line: print memory address
    print(' {:6x}:  '.format(start+k), end='')

    # print dump block in hex
    for i in range(0, BYTESSPERLINE):
        if (i % 4) == 0:
            print('  ', end='')
        
        if (k+i < length):
            # print hex data value
            print(' {:02x}'.format(rdata[k+i]), end='')
        else:
            # out of range, print white space till end of hex block
            print('   ', end='')

    print('     ', end='')

    # print dump block in ascii character
    for i in range(0, BYTESSPERLINE):
        if (k+i < length):
            # print ascii data value
            c = rdata[k+i]
            print('{}'.format(chr(c) if 32 <= c < 128 else '?'), end='')
        else:
            # out of range, print white space till end of hex block
            print('   ', end='')

    k += BYTESSPERLINE
    print()

print()
