
class VERA:
    ADDRx_L = 0x20
    ADDRx_M = 0x21
    ADDRx_H = 0x22
    DATA0 = 0x23
    DATA1 = 0x24
    CTRL = 0x25
    DC_SEL = 0x02
    DC_ADDRSEL = 0x01
    IEN = 0x26
    ISR = 0x27
    IRQLINE_L = 0x28
    # DCSEL=0: =>
    DC_VIDEO = 0x29
    OUTMODE_VGA = 0x01
    CURRENT_FIELD = 0x80
    SPRITES_ENABLE = 0x40
    LAYER1_ENABLE = 0x20
    LAYER0_ENABLE = 0x10
    CHROMA_DISABLE = 0x04
    DC_HSCALE = 0x2A
    DC_VSCALE = 0x2B
    DC_BORDER = 0x2C
    OUTPUT_MODE = 0x03
    # DCSEL=1: =>
    DC_HSTART = 0x29
    DC_HSTOP = 0x2A
    DC_VSTART = 0x2B
    DC_VSTOP = 0x2C
    # Layer 0
    L0_CONFIG = 0x2D
    BPP_1 = 0
    BPP_2 = 1
    BPP_4 = 2
    BPP_8 = 3
    BITMAP_MODE = 0x04
    T256C = 0x08
    MAP_WH_32T = 0
    MAP_WH_64T = 1
    MAP_WH_128T = 2
    MAP_WH_256T = 3
    L0_MAPBASE = 0x2E
    L0_TILEBASE = 0x2F
    TILE_WH_8P = 0
    TILE_WH_16P = 1
    L0_HSCROLL_L = 0x30
    L0_HSCROLL_H = 0x31
    L0_VSCROLL_L = 0x32
    L0_VSCROLL_H = 0x33
    # Layer 1
    L1_CONFIG = 0x34
    L1_MAPBASE = 0x35
    L1_TILEBASE = 0x36
    L1_HSCROLL_L = 0x37
    L1_HSCROLL_H = 0x38
    L1_VSCROLL_L = 0x39
    L1_VSCROLL_H = 0x3A
    # Audio
    AUDIO_CTRL = 0x3B
    AUDIO_RATE = 0x3C
    AUDIO_DATA = 0x3D
    # SPI SDCard
    SPI_DATA = 0x3E
    SPI_CTRL = 0x3F

    def __init__(self, icd):
        self.icd = icd

    # Dump all VERA IO Registers
    def vdump_regs(self):
        regs = self.icd.ioregs_read(VERA.ADDRx_L, 32)
        self.print_regs(regs)
    
    def print_regs(self, regs):
        # offest the array data by 32 just for our convenience
        regs = bytearray(0x20*[0]) + regs
        dcsel = regs[VERA.CTRL] & VERA.DC_SEL
        addrsel = regs[VERA.CTRL] & VERA.DC_ADDRSEL
        print("  ADDRx_H:M:L=0x.{:02X}:{:02X}:{:02X}".format(regs[VERA.ADDRx_H], regs[VERA.ADDRx_M], regs[VERA.ADDRx_L]))
        print("  DATA0=0x{:02X}, DATA1=0x{:02X}".format(regs[VERA.DATA0], regs[VERA.DATA1]))
        print("  CTRL=0x{:02X} (DCSEL={}, ADDRSEL={}), IEN=0x{:02X}, ISR=0x{:02X}, IRQLINE_L=0x{:02X}".format(
            regs[VERA.CTRL], dcsel >> 1, addrsel,
            regs[VERA.IEN], regs[VERA.ISR], regs[VERA.IRQLINE_L]
        ))
        if (dcsel == 0):
            # DCSEL=0
            print("  DCSEL=0 => DC_VIDEO=0x{:02X} (CurrentField={}, SpritesEna={}, L1_Ena={}, L0_Ena={}, ChromaDis={}, OutputMode={})".format(
                regs[VERA.DC_VIDEO], (regs[VERA.DC_VIDEO] & VERA.CURRENT_FIELD) >> 7, 
                (regs[VERA.DC_VIDEO] & VERA.SPRITES_ENABLE) >> 6,
                (regs[VERA.DC_VIDEO] & VERA.LAYER1_ENABLE) >> 5,
                (regs[VERA.DC_VIDEO] & VERA.LAYER0_ENABLE) >> 4,
                (regs[VERA.DC_VIDEO] & VERA.CHROMA_DISABLE) >> 2,
                (regs[VERA.DC_VIDEO] & VERA.OUTPUT_MODE)
            ))
            print("             DC_HSCALE=0x{:02X}, DC_VSCALE=0x{:02X}, DC_BORDER=0x{:02X}".format(
                regs[VERA.DC_HSCALE], regs[VERA.DC_VSCALE], regs[VERA.DC_BORDER]
            ))
        else:
            # DCSEL=1
            print("  DCSEL=1 => DC_HSTART=0x{:02X} ({}), DC_HSTOP=0x{:02X} ({})".format(
                regs[VERA.DC_HSTART], regs[VERA.DC_HSTART]*4, 
                regs[VERA.DC_HSTOP], regs[VERA.DC_HSTOP]*4
            ))
            print("             DC_VSTART=0x{:02X} ({}), DC_VSTOP=0x{:02X} ({})".format(
                regs[VERA.DC_VSTART], regs[VERA.DC_VSTART]*2, 
                regs[VERA.DC_VSTOP], regs[VERA.DC_VSTOP]*2
            ))
        # Layer 0
        print("  L0_CONFIG=0x{:02X}".format(regs[VERA.L0_CONFIG]))
        print("  L0_MAPBASE=0x{:02X}".format(regs[VERA.L0_MAPBASE]))
        print("  L0_TILEBASE=0x{:02X}".format(regs[VERA.L0_TILEBASE]))
        print("  L0_HSCROLL_H:L=0x.{:02X}:{:02X}".format(regs[VERA.L0_HSCROLL_H], regs[VERA.L0_HSCROLL_L]))
        print("  L0_VSCROLL_H:L=0x.{:02X}:{:02X}".format(regs[VERA.L0_VSCROLL_H], regs[VERA.L0_VSCROLL_L]))
        # Layer 1
        print("  L1_CONFIG=0x{:02X}".format(regs[VERA.L1_CONFIG]))
        print("  L1_MAPBASE=0x{:02X}".format(regs[VERA.L1_MAPBASE]))
        print("  L1_TILEBASE=0x{:02X}".format(regs[VERA.L1_TILEBASE]))
        print("  L1_HSCROLL_H:L=0x.{:02X}:{:02X}".format(regs[VERA.L1_HSCROLL_H], regs[VERA.L1_HSCROLL_L]))
        print("  L1_VSCROLL_H:L=0x.{:02X}:{:02X}".format(regs[VERA.L1_VSCROLL_H], regs[VERA.L1_VSCROLL_L]))
        # Audio
        print("  AUDIO_CTRL=0x{:02X}, AUDIO_RATE=0x{:02X}".format(regs[VERA.AUDIO_CTRL], regs[VERA.AUDIO_RATE]))
        # SPI
        print("  SPI_CTRL=0x{:02X}".format(regs[VERA.SPI_CTRL]))

    def vpoke(self, addr, data):
        self.icd.ioregs_write(VERA.ADDRx_L, [addr & 0xFF, (addr >> 8) & 0xFF, (addr >> 16) & 0x01])
        self.icd.iopoke(VERA.DATA0, data)

    def vpoke0_setup(self, addr, inc=1):
        self.icd.ioregs_write(VERA.ADDRx_L, [addr & 0xFF, (addr >> 8) & 0xFF, 
                                             ((addr >> 16) & 0x01) | (inc << 4)])


