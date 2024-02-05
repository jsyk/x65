/**
 * Terminal Demo, in 6502 mode.
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
    // VERA.address;
    // VERA.address_hi;
    VERA.data0 = data;
    // VERA.data0;
}

void vprint(uint8_t x, uint8_t y, const char *str)
{
    // calculate VRAM address from x/y coordinates
    uint16_t ci = 2*x + 2*128*y;
    // setup for the VRAM address, autoincrement
    VERA.address = ci & 0xFFFF;
    VERA.address_hi = 0 | (1 << 4);

    while (*str)
    {
        char c = *str;
        VERA.data0 = c;                 // character
        VERA.data0 = (COLOR_GRAY1 << 4) | (COLOR_LIGHTGREEN);         // backround and foreground color
        // vpoke(ci, c);              // character
        // vpoke(ci+1, 0x61);           // colors
        str++;
        // x++;
    }
}

int main()
{
    // printf("HELLO WORLD FROM VCHARTEST!\r\n");

    // ; setup the RED LED for pin driving
    // reg(VIA1_DDRB_REG) = 0x03;          // ; CPULED0, CPULED1
    VIA2.ddrb = 0x03;

     // # DCSEL=0, ADRSEL=0
    VERA.control = 0x00;
    // # Enable output to VGA 640x480, enable Layer0
    VERA.display.video = TV_VGA | LAYER0_ENABLE;
 
    // # DCSEL=0, ADRSEL=0
    VERA.control = 0x00;

    // characters are 8x8, visible screen 80 columns, 60 rows.
    // # Layer0 setup: Tile mode 1bpp, Map Width = 128 tiles, Map Height = 128 tiles ==> 16384 tiles, each 2B => 32768 B
    VERA.layer0.config = (MAP_WH_128T << 6) | (MAP_WH_128T << 4) | BPP_1;

    // # map entries start at address 0 of VRAM, and occupy 32kB
    const uint32_t mapbase_va = 0x00;
    VERA.layer0.mapbase = mapbase_va;

    // # tile (font) starts at 32kB offset
    const uint32_t tilebase_va = 0x8000;           // # v-addr 32768

    // # TileBase (font) starts at 32kB offset. Each tile is 8x8 pixels
    VERA.layer0.tilebase = ((tilebase_va >> 11) << 2);

    // configure addressing ptr at the font data (tilebase), autoincrement
    VERA.address = tilebase_va;
    VERA.address_hi = ((tilebase_va >> 16) & 1) | (1 << 4);
    // copy font data to VRAM
    for (int i = 0; i < SIZEOF_font8x8; i++)
    {
        VERA.data0 = font8x8[i];
    }

    // configure addressing ptr at the screen character data (map), autoincrement
    VERA.address = mapbase_va;
    VERA.address_hi = ((mapbase_va >> 16) & 1) | (1 << 4);
    // clear the virtual screen: 128 columns by 64 rows.
    for (int i = 0; i < 128*64; i++)
    {
        VERA.data0 = ' ';           // character index
        VERA.data0 = (COLOR_GRAY1 << 4) | (COLOR_WHITE);         // backround and foreground color
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
    // uint8_t c = 0;
    // for (int y = 0; y < 60; y++)
    // {
    //     for (int x = 0; x < 80; x++)
    //     {
    //         int ci = 2*x + 2*128*y;
    //         vpoke(ci, c);              // character
    //         vpoke(ci+1, x+y);           // colors
    //         c = (c + 1) & 0xFF;
    //     }
    // }

    vprint(0, 0, "Hello World! 1234!");

    vprint(0, 2, "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis risus. ");
    vprint(0, 3, "Nam quis nulla. Duis condimentum augue id magna semper rutrum. ");
    vprint(0, 4, "Nullam justo enim, consectetuer nec, ullamcorper ac, vestibulum in, elit. ");
    vprint(0, 5, "Mauris dolor felis, sagittis at, luctus sed, aliquam non, tellus. ");
    vprint(0, 6, "In laoreet, magna id viverra tincidunt, sem odio bibendum justo, ");
    vprint(0, 7, "vel imperdiet sapien wisi sed libero. Vestibulum erat nulla, ullamcorper nec, ");
    vprint(0, 8, "rutrum non, nonummy ac, erat. Mauris dolor felis, sagittis at, luctus sed, aliquam non, tellus. ");
    vprint(0, 9, "Mauris tincidunt sem sed arcu. ");


    vprint(10, 20, "X     X     666     5555                      ");
    vprint(10, 21, " X   X     6       5                          ");
    vprint(10, 22, "  X X      6       5             EEEE  U   U  ");
    vprint(10, 23, "   X       6666     5555         E     U   U  ");
    vprint(10, 24, "  X X      6   6        5        EEEE  U   U  ");
    vprint(10, 25, " X   X     6   6        5   ..   E     U   U  ");
    vprint(10, 26, "X     X     666     5555    ..   EEEE   UUU   ");

    // print("After Vpoke")
    // v.vdump_regs()

    int scr = 0;
    int dir = 1;

    while (1)
    { 
        VERA.layer0.vscroll = scr;
        delay(10000);
        scr = (scr + dir);
        if (scr == 7)
        {
            dir = -1;
        } else if (scr == 0)
        {
            dir = 1;
        }

    }

    return 0;
}
