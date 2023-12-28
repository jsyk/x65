#include <stdio.h>
#include <stdint.h>


/* wiznet W6100 base address in the memory address space */
#define WIZNET_BASE         0x9F80

/* wiznet BUS registers */
volatile uint8_t *IDM_ARH = (void*)(WIZNET_BASE + 0x00);     /* Indirect Mode High Address Register. It is most significant byte of the 16bit offset address */
volatile uint8_t *IDM_ARL = (void*)(WIZNET_BASE + 0x01);     /* Indirect Mode Low Address Register. It is least significant byte of the 16bit offset address */
volatile uint8_t *IDM_BSR = (void*)(WIZNET_BASE + 0x02);     /* Indirect Mode Block Select Register */
volatile uint8_t *IDM_DR = (void*)(WIZNET_BASE + 0x03);      /* Indirect Mode Data Register */

#define BSR_COMMON              0x00
#define BSR_SOCKn_REG(n)        (((n) << 5) | (1 << 3))
#define BSR_SOCKn_TXBUF(n)      (((n) << 5) | (2 << 3))
#define BSR_SOCKn_RXBUF(n)      (((n) << 5) | (3 << 3))

#define COMREG_CIDR0            0x0000              /* (Chip Identification Register) = 0x61 */
#define COMREG_CIDR1            0x0001              /* (Chip Identification Register 1) = 0x00 */

#define COMREG_NETLCKR          0x41F5              /* Network Lock Register) */
#define COMREG_SHAR             0x4120              /* MAC Source Hardware Address Register, 6 consecutive regs */
#define COMREG_GAR              0x4130              /* IPV4 Gateway IP Address Register, 4 consecutive regs */
#define COMREG_SUBR             0x4134              /* IPV4 Subnet Mask Register, 4 consecutive regs */
#define COMREG_SIPR             0x4138              /* IPv4 Source Address Register */
#define COMREG_PHYSR            0x3000              /* PHY Status Register */


#define SOCKREG_Sn_MR           0x0000              /* SOCKET n Mode Register */
#define SOCKREG_Sn_CR           0x0010              /* SOCKET n Command Register */
#define SOCKREG_Sn_SR           0x0030              /* SOCKET n Status Register */
#define SOCKREG_Sn_PORTR        0x0114              /* SOCKET n Source Port Register, 2 consecutive */
#define SOCKREG_Sn_TX_BSR       0x0200              /* SOCKET n TX Buffer Size Register */
#define SOCKREG_Sn_RX_BSR       0x0220              /* SOCKET n RX Buffer Size Register */
#define SOCKREG_Sn_DIPR         0x0120              /* SOCKET n Destination IPv4 Address Register */
#define SOCKREG_Sn_DPORTR       0x0140              /* SOCKET n Destination Port Register */
#define SOCKREG_Sn_IRCLR        0x0028              /* Sn_IR Clear Register */
#define SOCKREG_Sn_TX_WR        0x020C              /* SOCKET n TX Write Pointer Register, 2 consecutive */
#define SOCKREG_Sn_RX_RSR       0x0224              /* SOCKET n RX Received Size Register, 2 consec */
#define SOCKREG_Sn_RX_RD        0x0228              /* SOCKET n RX Read Pointer Register, 2 consec */

#define SOCK_INIT               0x13
#define SOCK_ESTABLISHED        0x17

/**
 * Deactive reset pin via AURA GPIO
 */
void reset_deact()
{
    // ./do-poke.py io 0x4c 0xf
    uint8_t *gpio_reset = (void*)0x9F4C;        // in AURA
    *gpio_reset = 0xF;
}

/**
 * Wiznet - Common Register area - Setup addressing
 */
void wiz_setup_comreg(uint16_t comreg_offs)
{
    *IDM_ARH = (uint8_t)(comreg_offs >> 8);
    *IDM_ARL = (uint8_t)comreg_offs;
    *IDM_BSR = BSR_COMMON;
}

void wiz_setup_reg(uint8_t bsr, uint16_t reg_offs)
{
    *IDM_ARH = (uint8_t)(reg_offs >> 8);
    *IDM_ARL = (uint8_t)reg_offs;
    *IDM_BSR = bsr;
}


void wiz_net_cfg_unlock()
{
    /* Network Unlock before set Network Information */
    //NETLCKR = 0x3A;
    wiz_setup_comreg(COMREG_NETLCKR);
    *IDM_DR = 0x3A;
}

void wiz_net_cfg_lock()
{
    /* Network lock */
    //NETLCKR = 0xA3;
    wiz_setup_comreg(COMREG_NETLCKR);
    *IDM_DR = 0xA3;
}

void source_hw_address()
{
    /* Source Hardware Address, 11:22:33:AA:BB:CC */
    //SHAR[0:5] = { 0x11, 0x22, 0x33, 0xAA, 0xBB, 0xCC };
    wiz_setup_comreg(COMREG_SHAR);
    // HACK ->>>
    *IDM_DR = 0x11;
    *IDM_DR = 0x22;
    *IDM_DR = 0x33;
    *IDM_DR = 0xAA;
    *IDM_DR = 0xBB;
    *IDM_DR = 0xCC;
}

void ipv4_net_config()
{
    /* Gateway IP Address, 192.168.0.1 */
    //GAR[0:3] = { 0xC0, 0xA8, 0x00, 0x01 };
    wiz_setup_comreg(COMREG_GAR);
    *IDM_DR = 192;
    *IDM_DR = 168;
    *IDM_DR = 0;
    *IDM_DR = 1;

    /* Subnet MASK Address, 255.255.255.0 */
    //SUBR[0:3] = { 0xFF, 0xFF, 0xFF, 0x00};
    wiz_setup_comreg(COMREG_SUBR);
    *IDM_DR = 255;
    *IDM_DR = 255;
    *IDM_DR = 255;
    *IDM_DR = 0;

    /* IP Address, 192.168.0.40 */
    //SIPR[0:3] = {0xC0, 0xA8,0x00, 0x64};
    wiz_setup_comreg(COMREG_SIPR);
    *IDM_DR = 192;
    *IDM_DR = 168;
    *IDM_DR = 0;
    *IDM_DR = 40;
}

void wiz_config_buffers()
{
    // assign 2Kbytes RX/TX buffer per SOCKET
    for (int n = 0; n < 7; n++)
    {
        wiz_setup_reg(BSR_SOCKn_REG(n), SOCKREG_Sn_TX_BSR);
        //Sn_TX_BSR = 2; // assign 2 Kbytes TX buffer per SOCKET
        *IDM_DR = 2;

        wiz_setup_reg(BSR_SOCKn_REG(n), SOCKREG_Sn_RX_BSR);
        //Sn_RX_BSR = 2; // assign 2 Kbytes RX buffer per SOCKET
        *IDM_DR = 2;
    }
}


void wiz_wait_linkup()
{
    /* wait until PHY Link is up */
    //while(PHYSR[LNK] != ‘0’);
    do
    {
        wiz_setup_comreg(COMREG_PHYSR);
    } while (!(*IDM_DR & 0x01));
}

void tcp4_open()
{
//START :
    do
    {
        //Sn_MR[3:0] = ‘0001’; /* set TCP4 Mode */
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_MR);
        *IDM_DR = 1;            // TCP4

        
        //Sn_PORTR[0:1] = {0, 80}; /* set PORT Number, 80 */
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_PORTR);
        *IDM_DR = 0x00;            // MSD
        *IDM_DR = 80;              // LSD

        //Sn_CR[OPEN] = ‘1’; /* set OPEN Command */
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
        *IDM_DR = 0x01;         // OPEN command

        //while(Sn_CR != 0x00); /* wait until OPEN Command is cleared*/
        do
        {
            wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
        } while (*IDM_DR != 0x00);      /* wait until OPEN Command is cleared*/
        
        /* check SOCKET Status */
        //if(Sn_SR != SOCK_INIT) goto START;
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_SR);
    } while (*IDM_DR != SOCK_INIT);
}

void tcp4_connect()
{
    /* set destination IP address, 192.168.0.12 */
    //Sn_DIPR[0:3] ={ 0xC0, 0xA8, 0x00, 0x0C};
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_DIPR);
    *IDM_DR = 192;
    *IDM_DR = 168;
    *IDM_DR = 0;
    *IDM_DR = 12;

    /* read back the DIPR to check! */
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_DIPR);
    printf("DIPR = %u.%u.%u.%u\n", *IDM_DR, *IDM_DR, *IDM_DR, *IDM_DR);

    /* set destination PORT number, 5000(0x1388) */
    //Sn_DPORTR[0:1] = {0x13, 0x88};
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_DPORTR);
    *IDM_DR = 0x00;            // MSD
    *IDM_DR = 80;              // LSD

    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
    //Sn_CR = CONNECT; /* set CONNECT command in TCP Mode */
    *IDM_DR = 0x04;         // CONNECT command

    //while(Sn_CR != 0x00); /* wait until CONNECT or CONNECT6 command is cleared */
    do
    {
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
    } while (*IDM_DR != 0x00);      /* wait until the Command is cleared*/
    
    //goto ESTABLISHED?;
}

void tcp4_established()
{
    /* checnk SOCKET status */
    do 
    {
        //if (Sn_SR == SOCK_ESTABLISHED)
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_SR);
    } while (*IDM_DR != SOCK_ESTABLISHED);

    // {
    //     Sn_IRCLR[CON] = ‘1’; /* clear SOCKET Interrupt */
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_IRCLR);
    *IDM_DR = 0x01;

    //     goto Received DATA? /* or goto Send DATA?; */
    // }
    // else if(Sn_IR[TIMEOUT] == ‘1’) goto Timeout?;
}

void tcp4_send()
{
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_TX_WR);
    uint16_t wrofs = (*IDM_DR << 8) | *IDM_DR;

    wiz_setup_reg(BSR_SOCKn_TXBUF(0), wrofs);
    *IDM_DR = 'G';
    *IDM_DR = 'E';
    *IDM_DR = 'T';
    *IDM_DR = ' ';
    *IDM_DR = '/';
    // *IDM_DR = 'a';
    // *IDM_DR = 'b';
    *IDM_DR = '\r';
    *IDM_DR = '\n';

    int wrcount = 7;

    wrofs += wrcount;

    /* check what has been written */
    wiz_setup_reg(BSR_SOCKn_TXBUF(0), wrofs);

    for (int i = 0; i < wrcount; ++i)
    {
        printf("%c", *IDM_DR);
    }
    printf("\n");

    /* increase Sn_TX_WR as send_size */
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_TX_WR);
    *IDM_DR = (wrofs >> 8);
    *IDM_DR = (wrofs & 0xFF);

    /* set SEND and SEND6 Command in each TCP and TCP6 Mode */
    //Sn_CR = SEND; /* set SEND command in TCP Mode */
    //while(Sn_CR != 0x00); /* wait until SEND or SEND6 Command is cleared */

    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
    *IDM_DR = 0x20;         // SEND command
    do
    {
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
    } while (*IDM_DR != 0x00);      /* wait until the Command is cleared*/
}

void tcp4_recv()
{
    /* check SOCKET RX buffer Received Size */
    //if (Sn_RX_RSR > 0) goto Receiving Process;
    uint16_t rx_size = 0;
    do
    {
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_RX_RSR);
        rx_size = (*IDM_DR << 8);       // MSD-first
        rx_size |= (*IDM_DR & 0xFF);    // LSD
    } while (rx_size == 0);

    printf("GOT %d BYTES:\n", rx_size);
    
    /* get Read offset */
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_RX_RD);
    uint16_t rd_offs = (*IDM_DR << 8);
    rd_offs |= (*IDM_DR & 0xFF);

    printf("RD OFFS = %u\n", rd_offs);

    /* read from RX buffer */
    wiz_setup_reg(BSR_SOCKn_RXBUF(0), rd_offs);

    for (int i = 0; (i < rx_size) /*&& (i < 50)*/; ++i)
    {
        uint8_t ch = *IDM_DR;
        // printf("  %X'%c'", ch, ch);
        printf("%c", ch);
    }


    /* increase Sn_RX_RD as get_size */
    //Sn_RX_RD += get_size;
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_RX_RD);
    rd_offs += rx_size;
    *IDM_DR = rd_offs >> 8;
    *IDM_DR = rd_offs;

    /* set RECV Command */
    wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
    *IDM_DR = 0x40;         // RECV command
    do
    {
        wiz_setup_reg(BSR_SOCKn_REG(0), SOCKREG_Sn_CR);
    } while (*IDM_DR != 0x00);      /* wait until the Command is cleared*/

}


int main()
{
    printf("WIZNET TEST\r\n");
    reset_deact();
    
    printf("WAITING FOR RESET DONE...\r\n");
    uint8_t cidr0, cidr1;
    do
    {
        wiz_setup_comreg(COMREG_CIDR0);
        cidr0 = *IDM_DR;
        cidr1 = *IDM_DR;
    } while ((cidr0 != 0x61) || (cidr1 != 0x00));
    
    wiz_setup_comreg(COMREG_CIDR0);
    printf("CIDR0 = %X\n", *IDM_DR);
    printf("CIDR1 = %X\n", *IDM_DR);
    printf("VER0 = %X\n", *IDM_DR);
    printf("VER1 = %X\n", *IDM_DR);

    // wait until PHY link up.
    printf("WAITING FOR LINKUP...\n");
    wiz_wait_linkup();
    
    wiz_net_cfg_unlock();
    source_hw_address();
    ipv4_net_config();
    wiz_net_cfg_lock();
    wiz_config_buffers();

    printf("OPENING SOCKET...\n");
    tcp4_open();
    printf("CONNECTING...\n");
    tcp4_connect();
    printf("WAITING FOR ESTABLISHED...\n");
    tcp4_established();
    printf("SENDING...\n");
    tcp4_send();
    printf("RECEIVING...\n");
    tcp4_recv();


    return 0;
}
