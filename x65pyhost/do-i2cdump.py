#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

# To read EUI-48 from the EEPROM 24AA025E48:
#   ./do-i2cdump.py 0x50 0xFA 6

# To read the MCP7940N RTC I2C registers:
#   ./do-i2cdump.py 0x6F 0x00 6

icd = ICD(x65ftdi.X65Ftdi())

apa = argparse.ArgumentParser(usage="%(prog)s [OPTION] area start length",
    description="Dump X65 I2C bus memory."
)

apa.add_argument(
    "-v", "--version", action="version", version = f"{apa.prog} version 1.0.0"
)

# define the arguments
apa.add_argument('device_address', help="Unshifted 7-bit I2C device address.")
apa.add_argument('memory_address', help="Memory address (8-bit) inside of the I2C device to read from.")
apa.add_argument('length', help="Number of bytes to read.")

# parse the arguments
args = apa.parse_args()

# extract the arguments
device_address = int(args.device_address, 0)
memory_address = int(args.memory_address, 0)
length = int(args.length, 0)


# Registers in the NORA register space for the I2C master
I2CCTRL = 0x5b
I2CSTAT = 0x5c
I2CDATA = 0x5d

# I2C master commands
CMD_START_ADDRESS = 0x01
CMD_SEND_DATA_READ_ACK = 0x02
CMD_RECV_DATA = 0x03
CMD_WRITE_ACK = 0x04
CMD_WRITE_NACK = 0x05
CMD_STOP = 0x07

# wait for a transaction to finish
def i2cm_wait():
    while (icd.ioregs_read(I2CSTAT, 1)[0] & 0x80 == 0x80):
        pass

# issue a command to the I2C master and wait until it is finished
def i2cm_cmd(cmd):
    icd.ioregs_write(I2CCTRL, [cmd])
    i2cm_wait()

def i2cm_read():
    return icd.ioregs_read(I2CDATA, 1)[0]


# generate STOP condition to be sure we are not in the middle of a transaction
i2cm_cmd(CMD_STOP)

# print("Reading ")

print("Addressing the I2C device 0x{:x}, to write.".format(device_address))
# write device address, WRITE TRANSACTION
icd.ioregs_write(I2CDATA, [device_address << 1])
# START transaction
i2cm_cmd(CMD_START_ADDRESS)
# check ACK in I2CDATA, bit 0
ack = i2cm_read()
print("  ACK: 0x{:02x}".format(ack))
if ack != 0:
    print("Error: NACK received => device not present, aborting.")
    exit(1)


print("Writing the memory address 0x{:x} to read from".format(memory_address))
# write memory address
icd.ioregs_write(I2CDATA, [memory_address])
# send data, read ack
i2cm_cmd(CMD_SEND_DATA_READ_ACK)
# check ACK in I2CDATA, bit 0
ack = i2cm_read()
print("  ACK: 0x{:02x}".format(ack))
if ack != 0:
    print("Error: NACK received => device refused the address, aborting.")
    exit(1)

print("Addressing the I2C device again, to read.")
# write device address, READ
icd.ioregs_write(I2CDATA, [(device_address << 1) | 1])
# START transaction
i2cm_cmd(CMD_START_ADDRESS)
# check ACK in I2CDATA, bit 0
ack = i2cm_read()
print("  ACK: 0x{:02x}".format(ack))
if ack != 0:
    print("Error: NACK received => device refused the address, aborting.")
    exit(1)

# read data
rdata = []

# read length bytes of data
for ii in range(length):
    # receive data
    i2cm_cmd(CMD_RECV_DATA)
    # read data from I2CDATA
    data = i2cm_read()
    # print("Data[{:d}]: 0x{:02x}".format(ii, data))
    rdata.append(data)
    # send ACK or NACK depending on the last byte
    if ii < length - 1:
        # ACK because there is more data to read
        i2cm_cmd(CMD_WRITE_ACK)
    else:
        # NACK because this is the last byte
        i2cm_cmd(CMD_WRITE_NACK)

# generate STOP condition
i2cm_cmd(CMD_STOP)

# number of printed bytes per line
BYTESSPERLINE = 16
print()

# print the data in hex and ascii
print("             +0 +1 +2 +3   +4 +5 +6 +7   +8 +9 +A +B   +C +D +E +F")

k = 0
while k < length:
    # start of line: print memory address
    print(' {:6x}:  '.format(memory_address+k), end='')

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
