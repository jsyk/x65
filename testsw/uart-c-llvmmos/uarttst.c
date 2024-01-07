/**
 * UART TEST, in 6502 mode.
 * Compiler: llvm-mos, generates .prg file
 * Can be loaded through ICD do-loadprg.py directly into CX16 running system.
*/
#include <stdio.h>
#include <stdint.h>

/* define register addresses */

#define USB_UART_CTRL       0x9F55
#define USB_UART_STAT       0x9F56
#define USB_UART_DATA       0x9F57

#define UART_CTRL_HWFLOW_EN             0x20

#define UART_STAT_IS_TX_FIFO_FULL       0x08
#define UART_STAT_IS_RX_FIFO_EMPTY      0x80

#define  reg8(x)             *((volatile uint8_t*)(x))

char rx_is_char()
{
    if (reg8(USB_UART_STAT) & UART_STAT_IS_RX_FIFO_EMPTY)
        return 1;
    else
        return 0;
}

void uart_puts(char *s)
{
    while (*s)
    {
        while ((reg8(USB_UART_STAT) & UART_STAT_IS_TX_FIFO_FULL))
        {
            /* wait */
        }
        reg8(USB_UART_DATA) = *s;
        s++;
    }
}

int main()
{
    printf("USB-UART TEST\r\n");

    printf("Original USB_UART_CTRL = 0x%x\n", reg8(USB_UART_CTRL));

    // enable HW flow control
    printf("Enabling HwFlowControl\n");
    reg8(USB_UART_CTRL) |= UART_CTRL_HWFLOW_EN;

    printf("USB_UART_CTRL = 0x%x\n", reg8(USB_UART_CTRL));
    printf("USB_UART_STAT = 0x%x\n", reg8(USB_UART_STAT));

    uart_puts("Hello World from USB-UART!\r\nHow are you folks?\r\n");

    char inc = 0;

    while (1)
    {
        while (reg8(USB_UART_STAT) & UART_STAT_IS_RX_FIFO_EMPTY)
        {
            /* wait */
        }
        // RX
        char c = reg8(USB_UART_DATA);
        printf("0x%x %c  ", c, c);
        // TX
        reg8(USB_UART_DATA) = c + inc;

        if (c == '\r')
            // add LF
            reg8(USB_UART_DATA) = '\n';

        // if (c == 'I')
        //     inc++;
        // if (c == 'D')
        //     inc--;
    }

    printf("PROGRAM FINISHED.\r\n");
    return 0;
}
