/*
 *  x65icd -- ICD tool for OpenX65 with FTDI-based USB/SPI interface,
 *
 *  Copyright (C) 2015  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2018  Piotr Esden-Tempski <piotr@esden.net>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  Relevant Documents:
 *  -------------------
 *  http://www.latticesemi.com/~/media/Documents/UserManuals/EI/icestickusermanual.pdf
 *  http://www.micron.com/~/media/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <getopt.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>

#ifdef _WIN32
#include <io.h> /* _setmode() */
#include <fcntl.h> /* _O_BINARY */
#endif

#include "mpsse.h"

static bool verbose = false;

// ---------------------------------------------------------
// ICD definitions
// ---------------------------------------------------------

#define BLOCKSIZE 		256
#define PAGESIZE		8192
#define SIZE_2MB 		(2048 * 1024)


#define CMD_GETSTATUS 		0x0
#define CMD_BUSMEM_ACC 		0x1
#define CMD_CPUCTRL 		0x2

#define nSRAM_OTHER_BIT 	4
#define nWRITE_READ_BIT 	5
#define ADR_INC_BIT 		6



// ---------------------------------------------------------
// Hardware specific CS, CReset, CDone functions
// ---------------------------------------------------------

static void set_flash_cs_creset(int cs_b, int creset_b)
{
	uint8_t gpio = 0;
	uint8_t direction = 0x03;

	if (!cs_b) {
		// ADBUS4 (GPIOL0)
		direction |= 0x10;
	}

	if (!creset_b) {
		// ADBUS7 (GPIOL3)
		direction |= 0x80;
	}

	mpsse_set_gpio_low(gpio, direction);
}

static bool get_cdone(void)
{
	// ADBUS6 (GPIOL2)
	return (mpsse_readb_low() & 0x40) != 0;
}

// ---------------------------------------------------------
// FLASH function implementations
// ---------------------------------------------------------

// bit masks of the signals on ACBUSx
#define ICD2NORAROM 		0x01			// ACBUS0
#define ICDCSN				0x02			// ACBUS1
#define ICD2VERAROM			0x04			// ACBUS2
#define VERA2FCSN			0x08			// ACBUS3
#define VERAFCSN			0x10			// ACBUS4
#define VERADONE			0x40			// ACBUS6
#define VERARSTN			0x80			// ACBUS7

#if 0
// configure the high-byte (ACBUSx) to route SPI to the flash,
// and disable ICD.
static void x65_select_flash()
{
	// drive high ICD2NORAROM, ICDCSN, keep others as IN.
	mpsse_set_gpio_high(ICD2NORAROM | ICDCSN | VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
				ICD2NORAROM | ICDCSN);
}
#endif

// configure the high-byte (ACBUSx) to route SPI to the ICD,
// and keep ICD high (deselect).
static void x65_idle()
{
	// drive low ICD2NORAROM (this unroutes SPI to flash),
	// drive high ICDCSN, keep others as IN.
	mpsse_set_gpio_high(ICDCSN | VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
				ICD2NORAROM | ICDCSN);
}

// the FPGA reset is released so also FLASH chip select should be deasserted
static void flash_release_reset()
{
	set_flash_cs_creset(1, 1);
}

// ICD chip select assert
// should only happen while ICD2NORAROM=Low
static void icd_chip_select()
{
	// drive low ICD2NORAROM (this unroutes SPI to flash),
	// drive low ICDCSN to activate the ICD
	mpsse_set_gpio_high(VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
				ICD2NORAROM | ICDCSN);
}

// ICD chip select deassert
static void icd_chip_deselect()
{
	// drive low ICD2NORAROM (this unroutes SPI to flash),
	// drive high ICDCSN to de-activate the ICD
	mpsse_set_gpio_high(ICDCSN | VERA2FCSN | VERAFCSN | VERADONE | VERARSTN, 
				ICD2NORAROM | ICDCSN);
}

// #define ICD_SRAM_WRITE		0x01
// #define ICD_SRAM_READ		0x03

#define ICD_SRAM_WRITE			(CMD_BUSMEM_ACC | (1 << ADR_INC_BIT))
#define ICD_SRAM_READ			(CMD_BUSMEM_ACC | (1 << nWRITE_READ_BIT) | (1 << ADR_INC_BIT))



static void icd_busread(uint8_t cmd, uint32_t maddr, int n, uint8_t *data)
{
	uint8_t hdr[5] = { cmd, maddr & 0xFF, maddr >> 8, maddr >> 16, 0x00 /*dummy*/ };

    icd_chip_select();
    mpsse_xfer_spi(hdr, 5);
    mpsse_xfer_spi(data, n);
    icd_chip_deselect();
}

static void icd_buswrite(uint8_t cmd, uint32_t maddr, int n, uint8_t *data)
{
	uint8_t hdr[4] = { cmd, maddr & 0xFF, maddr >> 8, maddr >> 16 };

    icd_chip_select();
    mpsse_xfer_spi(hdr, 4);
    mpsse_xfer_spi(data, n);
    icd_chip_deselect();
}


static void icd_sram_blockwrite(uint32_t maddr, int n, uint8_t *data)
{
	icd_buswrite(ICD_SRAM_WRITE, maddr, n, data);
}

static void icd_sram_blockread(uint32_t maddr, int n, uint8_t *data)
{
	icd_busread(ICD_SRAM_READ, maddr, n, data);
}

static void rand_fill_block(uint8_t *buf)
{
	for (int i = 0; i < BLOCKSIZE; i += 2)
	{
		uint16_t r = (uint16_t)rand();
		buf[i] = r;
		buf[i+1] = r >> 8;
	}
}

static int icd_sram_memtest(unsigned int seed, uint32_t mstart, int mbytes)
{
	uint8_t buf[BLOCKSIZE];
	int blocks = mbytes / BLOCKSIZE;

	printf("SRAM Memtest from 0x%08X to 0x%08X, rand seed 0x%08X\n",
			mstart, mstart + mbytes - 1, seed);

	srand(seed);

	for (int b = 0; b < blocks; b++)
	{
		rand_fill_block(buf);
		if ((b * BLOCKSIZE) % PAGESIZE == 0)
		{
			printf("  Writing page %d (0x%08X to 0x%08X)...\n", (b + mstart/BLOCKSIZE) * BLOCKSIZE / PAGESIZE,
					(b + mstart/BLOCKSIZE) * BLOCKSIZE, ((b+1) + mstart/BLOCKSIZE) * BLOCKSIZE - 1);
		}
		icd_sram_blockwrite(mstart + b * BLOCKSIZE, BLOCKSIZE, buf);
	}
	
	srand(seed);

	uint8_t buf2[BLOCKSIZE];
	int errors = 0;

	for (int b = 0; b < blocks; b++)
	{
		if ((b * BLOCKSIZE) % PAGESIZE == 0)
		{
			printf("  Reading page %d (0x%08X to 0x%08X)...\n", (b + mstart/BLOCKSIZE) * BLOCKSIZE / PAGESIZE,
					(b + mstart/BLOCKSIZE) * BLOCKSIZE, ((b+1) + mstart/BLOCKSIZE) * BLOCKSIZE - 1);
		}
		icd_sram_blockread(mstart + b * BLOCKSIZE, BLOCKSIZE, buf);
		rand_fill_block(buf2);
		if (memcmp(buf, buf2, BLOCKSIZE))
		{
			++errors;
			printf("  Error in page %d (0x08%X to 0x08%X)!\n", (b + mstart/BLOCKSIZE) * BLOCKSIZE / PAGESIZE,
						mstart + b*BLOCKSIZE, mstart + (b-1)*BLOCKSIZE - 1);
		}
	}

	printf("Memtest done with %d errors.\n", errors);
	return errors;
}

// ---------------------------------------------------------
// x65icd implementation
// ---------------------------------------------------------

static void help(const char *progname)
{
	fprintf(stderr, "ICD tool for OpenX65 computer // WORK IN PROGRESS.\n");
}

int main(int argc, char **argv)
{
	/* used for error reporting */
	const char *my_name = argv[0];
	for (size_t i = 0; argv[0][i]; i++)
		if (argv[0][i] == '/')
			my_name = argv[0] + i + 1;

	bool slow_clock = false;
	const char *devstr = NULL;
	int ifnum = 0;

#ifdef _WIN32
	_setmode(_fileno(stdin), _O_BINARY);
	_setmode(_fileno(stdout), _O_BINARY);
#endif

	static struct option long_options[] = {
		{"help", no_argument, NULL, -2},
		{NULL, 0, NULL, 0}
	};

	/* Decode command line parameters */
	int opt;
	// char *endptr;
	while ((opt = getopt_long(argc, argv, "d:I:vs", long_options, NULL)) != -1) {
		switch (opt) {
		case 'd': /* device string */
			devstr = optarg;
			break;
		case 'I': /* FTDI Chip interface select */
			if (!strcmp(optarg, "A"))
				ifnum = 0;
			else if (!strcmp(optarg, "B"))
				ifnum = 1;
			else if (!strcmp(optarg, "C"))
				ifnum = 2;
			else if (!strcmp(optarg, "D"))
				ifnum = 3;
			else {
				fprintf(stderr, "%s: `%s' is not a valid interface (must be `A', `B', `C', or `D')\n", my_name, optarg);
				return EXIT_FAILURE;
			}
			break;
		case 'v': /* provide verbose output */
			verbose = true;
			break;
		case 's': /* use slow SPI clock */
			slow_clock = true;
			break;
		case -2:
			help(argv[0]);
			return EXIT_SUCCESS;
		default:
			/* error message has already been printed */
			fprintf(stderr, "Try `%s --help' for more information.\n", argv[0]);
			return EXIT_FAILURE;
		}
	}

	/* Make sure that the combination of provided parameters makes sense */


	// ---------------------------------------------------------
	// Initialize USB connection to FT2232H
	// ---------------------------------------------------------

	fprintf(stderr, "init..\n");

    if (slow_clock)
    {
    	fprintf(stderr, "slow clock active.\n");
    }

	mpsse_init(ifnum, devstr, slow_clock);

	fprintf(stderr, "cdone: %s\n", get_cdone() ? "high" : "low");

	x65_idle();
	flash_release_reset();
	usleep(100000);

#if 0
    fprintf(stderr, "icd test #1:\n");
    icd_chip_select();

    uint8_t command[1] = { 0x0A };
    fprintf(stderr, "icd selected, sending command 0x%02x...\n", command[0]);
    mpsse_xfer_spi(command, 1);
    fprintf(stderr, "  got 0x%02X\n", command[0]);
	// usleep(100000);

    for (int i = 0; i < 8; ++i)
    {
        uint8_t data[1] = { 0x01 + i };
        mpsse_xfer_spi(data, 1);
    	// usleep(100000);
        fprintf(stderr, "[%d]  -> 0x%02x\n", i, (unsigned int)data[0]);
    }

    icd_chip_deselect();
#endif

#if 0
	usleep(100000);

    fprintf(stderr, "icd test #2:\n");
    icd_chip_select();
    uint8_t cmddata[9] = { 0xAA, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 };
    mpsse_xfer_spi(cmddata, 9);
    icd_chip_deselect();
    for (int i = 0; i < 9; ++i)
    {
        fprintf(stderr, "[%d] = 0x%02x\n", i, (unsigned int)cmddata[i]);
    }
#endif

	usleep(100000);

    // fprintf(stderr, "icd test #3 - sram write:\n");
    // icd_chip_select();
    // uint8_t cmddata[11] = { 0x01, 0x00, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE };
    // mpsse_xfer_spi(cmddata, 11);
    // icd_chip_deselect();
    // for (int i = 0; i < 11; ++i)
    // {
    //     fprintf(stderr, "[%d] = 0x%02x\n", i, (unsigned int)cmddata[i]);
    // }


    // fprintf(stderr, "icd test #4 - sram read:\n");
    // icd_chip_select();
    // uint8_t cmddataB[14] = { 0x03, 0x02, 0x00, 0x00, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA };
    // mpsse_xfer_spi(cmddataB, 14);
    // icd_chip_deselect();
    // for (int i = 0; i < 14; ++i)
    // {
    //     fprintf(stderr, "[%d] = 0x%02x\n", i, (unsigned int)cmddataB[i]);
    // }

	icd_sram_memtest(time(NULL), 0, SIZE_2MB);
	// icd_sram_memtest(111, 5000*BLOCKSIZE, 1000*BLOCKSIZE);

	x65_idle();

	// ---------------------------------------------------------
	// Exit
	// ---------------------------------------------------------

	fprintf(stderr, "Bye.\n");
	mpsse_close();
	return 0;
}
