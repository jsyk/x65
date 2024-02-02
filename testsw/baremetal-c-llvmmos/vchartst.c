/**
 * Minimal VERA CHAR-TEST, in 6502 mode.
 * Compiler: llvm-mos, generates .rom file
 */
#include <stdint.h>
#include <stdio.h>
#include "x65.h"
#include "font8x8.h"

#define reg(x)          (*(volatile uint8_t*)x)


static void delay(int x)
{
    volatile int i;
    for (i = 0; i < x; ++i)
    {
        /* wait */
    }
}

void __putchar(char c)
{
    while (NORA.usb_uart_stat & NORA_UART_IS_TX_FIFO_FULL)
        ;
    NORA.usb_uart_data = c;
}

const static char tohex[] = "0123456789ABCDEF";

#define LAYER0_ENABLE       0x10

#define     MAP_WH_32T  0
#define     MAP_WH_64T  1
#define     MAP_WH_128T  2
#define     MAP_WH_256T  3

#define     BPP_1  0
#define     BPP_2  1
#define     BPP_4  2
#define     BPP_8   3

static inline void vpoke(uint32_t addr, uint8_t data)
{
    // self.icd.ioregs_write(VERA.ADDRx_L, [addr & 0xFF, (addr >> 8) & 0xFF, (addr >> 16) & 0x01])
    VERA.address = addr & 0xFFFF;
    VERA.address_hi = (addr >> 16) & 1;
    VERA.address;
    VERA.address_hi;
    VERA.data0 = data;
    VERA.data0;
}

void vprint(uint8_t x, uint8_t y, const char *str)
{
    while (*str)
    {
        char c = *str;
        int ci = 2*x + 2*128*y;
        vpoke(ci, c);              // character
        vpoke(ci+1, 0x61);           // colors
        str++;
        x++;
    }
}

int main()
{
    // printf("HELLO WORLD FROM VCHARTEST!\r\n");

    // ; setup the RED LED for pin driving
    // reg(VIA1_DDRB_REG) = 0x03;          // ; CPULED0, CPULED1
    VIA2.ddrb = 0x03;

    // int iter = 0;

    // while (1)
    // {
    // }

    // # DCSEL=0, ADRSEL=0
    VERA.control = 0x00;
    // # Enable output to VGA, enable Layer0
    VERA.display.video = TV_VGA | LAYER0_ENABLE;
    // icd.iopoke(v.DC_VIDEO, v.OUTMODE_VGA | v.LAYER0_ENABLE)

    // # DCSEL=0, ADRSEL=0
    // icd.iopoke(v.CTRL, 0x00)
    VERA.control = 0x00;

    // print("Dump with DCSEL=0, ADDRSEL=0")
    // v.vdump_regs()

    // print("Dump with DCSEL=1, ADDRSEL=0")
    // icd.iopoke(v.CTRL, v.DC_SEL)
    // v.vdump_regs()

    // # DCSEL=0, ADRSEL=0
    // icd.iopoke(v.CTRL, 0x00)
    VERA.control = 0x00;

    // # Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
    // icd.iopoke(v.L0_CONFIG, (v.MAP_WH_128T << 6) | (v.MAP_WH_128T << 4) | VERA.BPP_1)
    VERA.layer0.config = (MAP_WH_128T << 6) | (MAP_WH_128T << 4) | BPP_1;

    // # map entries start at address 0 of VRAM, and occupy 32kB
    // icd.iopoke(v.L0_MAPBASE, 0x00)
    VERA.layer0.mapbase = 0x00;

    // # tile (font) starts at 32kB offset
    uint32_t tilebase_va = 0x8000;           // # v-addr 32768
    // # TileBase starts at 32kB offset. Each tile is 8x8 pixels
    // icd.iopoke(v.L0_TILEBASE, ((tilebase_va >> 11) << 2))
    VERA.layer0.tilebase = ((tilebase_va >> 11) << 2);

    // printf("%d", font8x8[0]);

    // # open 8x8 font
    // fontfile = open("../testsw/testroms/font8x8.bin", mode="rb")
    // fontdata = fontfile.read(2048)
    // # write font data to the tile memory
    // v.vpoke0_setup(tilebase_va, 1)
    
    VERA.address = tilebase_va;
    VERA.address_hi = ((tilebase_va >> 16) & 1) | (1 << 4);



    // for a in range(0, 2048):
        // icd.iopoke(v.DATA0, fontdata[a])
    for (int i = 0; i < SIZEOF_font8x8; i++)
    {
        VERA.data0 = font8x8[i];
    }

    // VERA.address_hi = 0;
    // test the address register

    // for (int i = 0; i < 256; i++)
    // {
    //     VERA.address = i;
    //     VERA.address;
    // }

    // while (1)
    // {
    //     VERA.address = 0xFF;
    //     VERA.address;
    // }

    // # write character/color data in the map:
    // # a tile map containing tile map entries, which are 2 bytes each:
    // # Offset 	Bit 7 	Bit 6 	Bit 5 	Bit 4 	Bit 3 	Bit 2 	Bit 1 	Bit 0
    // # 0 	    Character index
    // # 1 	    Background color 	            Foreground color
    // # v.vpoke0_setup(0, 1)
    uint8_t c = 0;
    for (int y = 0; y < 60; y++)
    {
        for (int x = 0; x < 80; x++)
        {
            int ci = 2*x + 2*128*y;
            vpoke(ci, c);              // character
            vpoke(ci+1, x+y);           // colors
            c = (c + 1) & 0xFF;
        }
    }

    vprint(0, 0, "Hello World! 1234!");

    // print("After Vpoke")
    // v.vdump_regs()

    while (1) { }

    return 0;
}
