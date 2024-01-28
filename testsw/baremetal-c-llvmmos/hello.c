/**
 * Minimal HELLO WORLD, in 6502 mode.
 * Compiler: llvm-mos, generates .prg file
 */
#include <stdint.h>
#include <stdio.h>
#include "x65.h"


// ; VIA1 - for LEDs
// #define VIA1_ORB_IRB_REG    0x9F00
// #define VIA1_DDRB_REG       0x9F02

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

int main()
{
    printf("HELLO WORLD FROM C!\r\n");

    // ; setup the RED LED for pin driving
    // reg(VIA1_DDRB_REG) = 0x03;          // ; CPULED0, CPULED1
    VIA2.ddrb = 0x03;

    int iter = 0;

    while (1)
    {
        // reg(VIA1_ORB_IRB_REG) &= 0xFC;
        VIA2.prb &= 0xFC;

        // delay(10000);

        // reg(VIA1_ORB_IRB_REG) |= 0x03;
        VIA2.prb |= 0x03;

        // delay(10000);

        // printf("HELLO WORLD #%d FROM C!\r\n", iter);
        // ++iter;

        if (NORA.ps2_stat & NORA_PS2_IS_KBD_BUF_NONEMPTY)
        {
            unsigned char c = NORA.ps2k_buf;
            // __putchar(c);
            __putchar('[');
            __putchar(tohex[c >> 4]);
            __putchar(tohex[c & 0x0F]);
            __putchar(']');
            if (c & 0x80)
            {
                __putchar('\r');
                __putchar('\n');
            }
        }

        if (NORA.ps2_stat & NORA_PS2_IS_MOUSE_BUF_3FILLED)
        {
            unsigned char c1 = NORA.ps2m_buf;
            unsigned char c2 = NORA.ps2m_buf;
            unsigned char c3 = NORA.ps2m_buf;

            /* clear rest */
            while (NORA.ps2_stat & NORA_PS2_IS_MOUSE_BUF_NONEMPTY)
            {
                NORA.ps2m_buf;
            }

            __putchar('{');
            __putchar(tohex[c1 >> 4]);
            __putchar(tohex[c1 & 0x0F]);
            __putchar(',');
            __putchar(tohex[c2 >> 4]);
            __putchar(tohex[c2 & 0x0F]);
            __putchar(',');
            __putchar(tohex[c3 >> 4]);
            __putchar(tohex[c3 & 0x0F]);
            __putchar('}');
        }
    }

    return 0;
}
