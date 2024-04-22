#!/usr/bin/python3
import x65ftdi
import argparse
from icd import *

icd = ICD(x65ftdi.X65Ftdi())


I2CCTRL = 0x5b
I2CSTAT = 0x5c
I2CDATA = 0x5d

CMD_START_ADDRESS = 0x01
CMD_SEND_DATA_READ_ACK = 0x02
CMD_RECV_DATA = 0x03
CMD_WRITE_ACK = 0x04
CMD_WRITE_NACK = 0x05
CMD_STOP = 0x07

EEPROM_ADDR = 0xA0

# wait for a transaction to finish
def i2cm_wait():
    while (icd.ioregs_read(I2CSTAT, 1)[0] & 0x80 == 0x80):
        pass

# issue a command to the I2C master and wait until it is finished
def i2cm_cmd(cmd):
    icd.ioregs_write(I2CCTRL, [cmd])
    i2cm_wait()



# generate STOP condition to be sure we are not in the middle of a transaction
i2cm_cmd(CMD_STOP)

print("Reading EUI-48 from 24AA025E48 EEPROM")

print("Addressing the EEPROM device, to write.")
# write device address: 0xA0 = the 24AA025E48 EEPROM, WRITE TRANSACTION
icd.ioregs_write(I2CDATA, [EEPROM_ADDR])
# START transaction
i2cm_cmd(CMD_START_ADDRESS)
# check ACK in I2CDATA, bit 0
print("ACK: 0x{:02x}".format(icd.ioregs_read(I2CDATA, 1)[0]))


print("Writing the memory address to read from")
# write memory address: the EUI-48 starts at the address 0xFA
icd.ioregs_write(I2CDATA, [0xFA])
# send data, read ack
i2cm_cmd(CMD_SEND_DATA_READ_ACK)
# check ACK in I2CDATA, bit 0
print("ACK: 0x{:02x}".format(icd.ioregs_read(I2CDATA, 1)[0]))

print("Addressing the EEPROM device, to read.")
# write device address: 0xA0 = the 24AA025E48 EEPROM, READ
icd.ioregs_write(I2CDATA, [EEPROM_ADDR | 1])
# START transaction
i2cm_cmd(CMD_START_ADDRESS)
# check ACK in I2CDATA, bit 0
print("ACK: 0x{:02x}".format(icd.ioregs_read(I2CDATA, 1)[0]))

# read 6 bytes of data EUI-48
for ii in range(6):
    # receive data
    i2cm_cmd(CMD_RECV_DATA)
    # read data from I2CDATA
    data = icd.ioregs_read(I2CDATA, 1)[0]
    print("Data[{:d}]: 0x{:02x}".format(ii, data))
    # send ACK
    i2cm_cmd(CMD_WRITE_ACK)

# generate STOP condition
i2cm_cmd(CMD_STOP)
