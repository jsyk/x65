# from pyftdi.ftdi import Ftdi
import pyftdi.spi
import random

# user: run ftdi_urls.py first

# Instantiate a SPI controller
spi = pyftdi.spi.SpiController()

# Configure the first interface (IF/1) of the first FTDI device as a
# SPI master
spi.configure('ftdi://ftdi:2232/1')

# Get a SPI port to a SPI slave w/ /CS on A*BUS3 and SPI mode 0 @ 6MHz
slave = spi.get_port(cs=0, freq=1E6, mode=0)

# Get GPIO port to manage extra pins, use A*BUS4 as GPO, A*BUS4 as GPI
gpio = spi.get_gpio()
# gpio.set_direction(0x30, 0x10)


# // ---------------------------------------------------------
# // Hardware specific CS, CReset, CDone functions
# // ---------------------------------------------------------

# // bit masks of the signals on ADBUSx (low byte)
PIN_SCK  = 0x0001
PIN_MOSI = 0x0002
PIN_MISO = 0x0004
PIN_NORAFCSN = 0x0010         # // ADBUS4 (GPIOL0) (FLASHCSN)
PIN_NORADONE = 0x0040           # // ADBUS6 (GPIOL2)
PIN_NORARSTN = 0x0080         # // ADBUS7 (GPIOL3)
# // bit masks of the signals on ACBUSx (high byte)
PIN_ICD2NORAROM = 0x0100			#// ACBUS0
PIN_ICDCSN = 0x0200			        #// ACBUS1
PIN_AURARSTN = 0x0400		        #// ACBUS2 (was ICD2VERAROM)
PIN_AURAFCSN = 0x0800			    #// ACBUS3 (was VERA2FCS)
PIN_VERAFCSN = 0x1000			    #// ACBUS4
PIN_VAFCDONE = 0x4000			    #// ACBUS6 (was VERADONE)
PIN_VERARSTN = 0x8000			    #// ACBUS7

PINS_ALL = PIN_NORAFCSN | PIN_NORADONE | PIN_NORARSTN | PIN_ICD2NORAROM | PIN_ICDCSN | PIN_AURARSTN | PIN_AURAFCSN | PIN_VERAFCSN | PIN_VAFCDONE | PIN_VERARSTN


# def set_flash_cs_creset(cs_b, creset_b):
# 	gpio = 0
# 	direction = 0x03

# 	if (not cs_b):
# 		# // ADBUS4 (GPIOL0)
# 		direction |= 0x10

# 	if (not creset_b):
# 		# // ADBUS7 (GPIOL3)
# 		direction |= 0x80

# 	mpsse_set_gpio_low(gpio, direction);
#     gpio.set_direction(gpio, 


# static bool get_cdone(void)
# {
# 	// ADBUS6 (GPIOL2)
# 	return (mpsse_readb_low() & 0x40) != 0;
# }


# #if 0
# // configure the high-byte (ACBUSx) to route SPI to the flash,
# // and disable ICD.
# static void x65_select_flash()
# {
# 	// drive high ICD2NORAROM, ICDCSN, keep others as IN.
# 	mpsse_set_gpio_high(ICD2NORAROM | ICDCSN | VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
# 				ICD2NORAROM | ICDCSN);
# }
# #endif

# // configure the high-byte (ACBUSx) to route SPI to the ICD,
# // and keep ICD high (deselect).
def pinout_idle():
    # for all GPIOs, configure just ICD2NORAROM and ICDCSN as outputs
    gpio.set_direction(PINS_ALL,
                        PIN_ICD2NORAROM | PIN_ICDCSN)
    # // drive low ICD2NORAROM (this unroutes SPI to flash),
    # // drive high ICDCSN, all others are IN.
    gpio.write(PIN_ICDCSN)


# // ICD chip select assert
# // should only happen while ICD2NORAROM=Low
def icd_chip_select():
    # // drive low ICD2NORAROM (this unroutes SPI to flash),
    # // drive low ICDCSN to activate the ICD
    gpio.write(0)
    # mpsse_set_gpio_high(VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
    # 			ICD2NORAROM | ICDCSN);

# // ICD chip select deassert
def icd_chip_deselect():
    # // drive low ICD2NORAROM (this unroutes SPI to flash),
    # // drive high ICDCSN to de-activate the ICD
    gpio.write(PIN_ICDCSN)
    # mpsse_set_gpio_high(ICDCSN | VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
    # 			ICD2NORAROM | ICDCSN);



BLOCKSIZE = 256
PAGESIZE = 8192
SIZE_2MB =	(2048 * 1024)


CMD_GETSTATUS =	0x0
CMD_BUSMEM_ACC = 0x1
CMD_CPUCTRL = 0x2
CMD_READTRACE =	0x3

nSRAM_OTHER_BIT =	4
nWRITE_READ_BIT =	5
ADR_INC_BIT =		6


ICD_SRAM_WRITE	= (CMD_BUSMEM_ACC | (1 << ADR_INC_BIT))
ICD_SRAM_READ =	(CMD_BUSMEM_ACC | (1 << nWRITE_READ_BIT) | (1 << ADR_INC_BIT))



def icd_busread(cmd, maddr, n):
    hdr = bytes( [cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF, 0x00 ] )
    icd_chip_select()
    rxdata = slave.exchange(hdr, n+len(hdr), start=False, stop=False, duplex=True)
    # slave.write(hdr, start=False, stop=False, droptail=1)
    # rxdata = slave.read(n, start=False, stop=False)
    icd_chip_deselect()
    return rxdata[5:]

def icd_buswrite(cmd, maddr, data):
    hdr = bytes([cmd, maddr & 0xFF, (maddr >> 8) & 0xFF, (maddr >> 16) & 0xFF ])
    icd_chip_select()
    slave.write(hdr,  start=False, stop=False)
    slave.write(data, start=False, stop=False)
    icd_chip_deselect()


def icd_sram_blockwrite(maddr, data):
    icd_buswrite(ICD_SRAM_WRITE, maddr, data)

def icd_sram_blockread(maddr, n):
    return icd_busread(ICD_SRAM_READ, maddr, n)

def icd_sram_memtest(seed, mstart, mbytes):
    # uint8_t buf[BLOCKSIZE];
    blocks = int(mbytes / BLOCKSIZE)

    print("SRAM Memtest from 0x{:x} to 0x{:x}, rand seed 0x{:x}\n".format(
            mstart, mstart + mbytes - 1, seed));

    # restart rand sequence
    random.seed(seed)

    for b in range(0, blocks):
        buf = random.randbytes(BLOCKSIZE)
        if ((b * BLOCKSIZE) % PAGESIZE == 0):
            print("  Writing page 0x{:x} (0x{:x} to 0x{:x})...\n".format(int((b + mstart/BLOCKSIZE) * BLOCKSIZE / PAGESIZE),
                    int((b + mstart/BLOCKSIZE) * BLOCKSIZE), int((b+1) + mstart/BLOCKSIZE) * BLOCKSIZE - 1))
        
        icd_sram_blockwrite(mstart + b * BLOCKSIZE, buf);
    
    # restart rand sequence
    random.seed(seed)
    
    errors = 0

    for b in range(0, blocks):
        if ((b * BLOCKSIZE) % PAGESIZE == 0):
            print("  Reading page 0x{:x} (0x{:x} to 0x{:x})...\n".format(int((b + mstart/BLOCKSIZE) * BLOCKSIZE / PAGESIZE),
                    int(b + mstart/BLOCKSIZE) * BLOCKSIZE, int((b+1) + mstart/BLOCKSIZE) * BLOCKSIZE - 1))
        
        buf1 = icd_sram_blockread(mstart + b * BLOCKSIZE, BLOCKSIZE)
        buf2 = random.randbytes(BLOCKSIZE)
        # print('buf1={}'.format(buf1.hex()))
        # print('buf2={}'.format(buf2.hex()))
        if buf1 != buf2:
            errors += 1
            print("  Error in page 0x{:x} (0x{:x} to 0x{:x})!\n".format(int((b + mstart/BLOCKSIZE) * BLOCKSIZE / PAGESIZE),
                        mstart + b*BLOCKSIZE, mstart + (b-1)*BLOCKSIZE - 1))

    print("Memtest done with {} errors.\n".format(errors))
    return errors


def icd_cpu_ctrl(run_cpu, cstep_cpu, reset_cpu):
    run_cpu &= 1
    cstep_cpu &= 1
    reset_cpu &= 1

    hdr = bytes([ CMD_CPUCTRL | (run_cpu << 4) | (cstep_cpu << 5), reset_cpu ])

    icd_chip_select()
    slave.write(hdr,  start=False, stop=False)
    icd_chip_deselect()


def icd_cpu_read_trace(tbuflen):
    #                        /*dummy*/
    hdr = bytes([ CMD_READTRACE, 0  ])

    icd_chip_select();
    rxdata = slave.exchange(hdr, tbuflen+1+len(hdr), start=False, stop=False, duplex=True)
    icd_chip_deselect()

    is_valid = rxdata[2] & 1
    is_ovf = rxdata[2] & 2
    # print('icd_cpu_read_trace got {}'.format(rxdata.hex()))

    return (is_valid, is_ovf, rxdata[3:])


TRACE_FLAG_RWN =		1
TRACE_FLAG_VECTPULL =	8
TRACE_FLAG_MLOCK =		16
TRACE_FLAG_SYNC =		32

w65c02_dismap = [
    "BRK s", "ORA (zp,X)", "?", "?", "TSB zp", "ORA zp", "ASL zp", "RMB0 zp", "PHP s", "ORA #", "ASL A", "?", "TSB A", "ORA a", "ASL a", "BBR0 r",
    "BPL r", "ORA (zp),Y", "ORA (zp)", "?", "TRB zp", "ORA zp,X", "ASL zp,X", "RMB1 zp", "CLC i", "ORA a,Y", "INC A", "?", "TRB a", "ORA a,x", "ASL a,x", "BBR1 r",
    "JSR a", "AND (zp,X)", "?", "?", "BIT zp", "AND zp", "ROL zp", "RMB2 zp", "PLP s", "AND #", "ROL A", "?", "BIT a", "AND a", "ROL a", "BBR2 r",
    "BMI r", "AND (zp),Y", "AND (zp)", "?", "BIT zp,X", "AND zp,X", "ROL zp,X", "RMB3 zp", "SEC i", "AND a,Y", "DEC A", "?", "BIT a,X", "AND a,X", "ROL a,X", "BBR3 r",
    "RTI s", "EOR (zp,X)", "?", "?", "?", "EOR zp", "LSR zp", "RMB4 zp", "PHA s", "EOR #", "LSR A", "?", "JMP a", "EOR a", "LSR a", "BBR4 r",
    "BVC r", "EOR (zp),Y", "EOR (zp)", "?", "?", "EOR zp,X", "LSR zp,X", "RMB5 zp", "CLI i", "EOR a,Y", "PHY s", "?", "?", "EOR a,X", "LSR a,X", "BBR5 r",
    "RTS s", "ADC (zp,X)", "?", "?", "STZ zp", "ADC zp", "ROR zp", "RMB6 zp", "PLA s", "ADC #", "ROR A", "?", "JMP (a)", "ADC a", "ROR a", "BBR6 r",
    "BVS s", "ADC (zp),Y", "ADC (zp)", "?", "STZ zp,X", "ADC zp,X", "ROR zp,X", "RMB7 zp", "SEI i", "ADC a,Y", "PLY s", "?", "JMP (a,X)", "ADC a,X", "ROR a,X", "BBR7 r",
    "BRA r", "STA (zp,X)", "?", "?", "STY zp", "STA zp", "STX zp", "SMB0 zp", "DEY i", "BIT #", "TXA i", "?", "STY a", "STA a", "STX a", "BBS0 r",
    "BCC r", "STA (zp),Y", "STA (zp)", "?", "STY zp,X", "STA zp,X", "STX zp,Y", "SMB1 zp", "TYA i", "STA a,Y", "TXS i", "?", "STZ a", "STA a,X", "STZ a,X", "BBS1 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    # // TBD... lines B-F
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r",
    "LDY #", "LDA (zp,X)", "LDX #", "?", "LDY zp", "LDA zp", "LDX zp", "SMB2 zp", "TAY i", "LDA #", "TAX i", "?", "LDY A", "LDA a", "LDX a", "BBS2 r"
]


def read_print_trace():
    tbuflen = 5
    is_valid, is_ovf, tbuf = icd_cpu_read_trace(tbuflen)

    print("TraceBuf: V:{} O:{}  CA:{:4x}  CD:{:2x}  ctr:{:2x}  sta:{:2x}:{}{}{}{}     {}".format(
            ('*' if is_valid else '-'),
            ('*' if is_ovf else '-'),
            tbuf[4] * 256 + tbuf[3],  #/*CA:*/
            tbuf[2],  #/*CD:*/
            tbuf[1],  #/*ctr:*/
            #/*sta:*/ 
            tbuf[0], ('r' if tbuf[0] & TRACE_FLAG_RWN else 'W'), 
            ('-' if tbuf[0] & TRACE_FLAG_VECTPULL else 'v'), 
            ('-' if tbuf[0] & TRACE_FLAG_MLOCK else 'L'), 
            ('S' if tbuf[0] & TRACE_FLAG_SYNC else '-'),
            (w65c02_dismap[tbuf[2]] if tbuf[0] & TRACE_FLAG_SYNC else "")
        ))


# ------------------------------------------------------
pinout_idle()
icd_chip_deselect()

# icd_sram_blockwrite(0, bytes([0xDE, 0xAD]))
# rxdata = icd_sram_blockread(0, 16)
# print('rx={}'.format(rxdata.hex()))
# print(len(rxdata))

# icd_sram_memtest(123, 0, SIZE_2MB)


# // stop cpu, activate the reset
icd_cpu_ctrl(0, 0, 1)

icd_sram_memtest(12, 0, 8192)

# // icd_sram_memtest(time(NULL), 0, SIZE_2MB);

# // icd_sram_memtest(111, 5000*BLOCKSIZE, 1000*BLOCKSIZE);


microhello = bytes([
    # // FFF0: any vector starts
    0xA9, 0x01,				#// LDA  #1
    0x48,					#// PHA
    0xA9, 0x02,				#// LDA  #2
    0x68,					#// PLA
    0x1A,					#// INC  A
    0x80, 0xFF-7+1,				#// BRA  -7   (@PHA)
    
    0x00,
    
    # // FFFA,B = NMI
    0xF0, 0xFF,
    # // FFFC,D = RES
    0xF0, 0xFF,
    # // FFFE,F = BRK, IRQ
    0xF0, 0xFF,
])

# // write startup code at the very end of ROMBANK #31, where the CPU starts
icd_sram_blockwrite(255 * 8192 + 8192-len(microhello), microhello);

# // stop cpu, activate the reset
print("CPU Stop & Reset\n")
icd_cpu_ctrl(0, 0, 1)
read_print_trace()
read_print_trace()

print("CPU Step & Reset\n")
# // step the cpu while reset is active for some time
for i in  range(0, 10):
    icd_cpu_ctrl(0, 1, 1)
    read_print_trace()

print("CPU Step:\n")
# // deactivate the reset, step the cpu
for i in range(0, 32):
    icd_cpu_ctrl(0, 1, 0)
    print("Step #{}".format(i))
    read_print_trace()

# // run
# icd_cpu_ctrl(1, 0, 0);
#endif


# Assert GPO pin
# gpio.write(0x10)
# Write to SPI slace
# slave.write(b'hello world!')
# Release GPO pin
# gpio.write(0x00)
# Test GPI pin
# pin = bool(gpio.read() & 0x20)
