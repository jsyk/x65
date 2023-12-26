#include <stdio.h>
#include <stdint.h>

volatile uint8_t *RAMBLOCK_REG = (void*)0;

uint8_t *RAMBLOCK_FRAME = (void*)0xA000;

#define BLOCK_SIZE          8192
#define FROM_RAMBLOCK       1
#define TOP_RAMBLOCK        127

/**
 * XORShift algorithm - credit to George Marsaglia!
 * @param a initial state
 * @return new state
 */
uint32_t xorShift32(uint32_t a)
{
    a ^= (a << 13);
    a ^= (a >> 17);
    a ^= (a << 5);
    return a;
}

/**
 * Write a pseudo-random pattern starting at the memory address start, 
 * count bytes, with initial seed.
 */
void patwrite(uint8_t *start, unsigned int count, uint32_t *seed)
{
    uint32_t sd = *seed;
    while (count)
    {
        sd = xorShift32(sd);
        // printf("%d ", (uint8_t)sd);
        *start = (uint8_t)sd;
        start++;
        count--;
    }
    *seed = sd;
}

/**
 * Read bytes from start, count bytes, and check them against
 * the pseudo-random sequence starting from the seed.
 */
int patcheck(uint8_t *start, unsigned int count, uint32_t *seed)
{
    uint32_t sd = *seed;
    int errors = 0;
    while (count)
    {
        sd = xorShift32(sd);
        // printf("%d ", (uint8_t)sd);
        if (*start != (uint8_t)sd)
        {
            // different byte!
            printf("ERROR: RAMBLOCK %u, ADDR $%X: EXP $%X, FOUND $%X\r\n",
                    *RAMBLOCK_REG, (uint16_t)start, (uint8_t)sd, *start);
            errors++;
        }
        start++;
        count--;
    }
    *seed = sd;
    return errors;
}

int main()
{
    printf("MEMORY TEST\r\n");

    // we start with seed 123
    uint32_t seed = 123;
    uint32_t run_iter = 1;
    uint32_t tot_errors = 0;

    while (1)
    {
        uint32_t seed_run = seed;
        uint32_t errors = 0;
        printf("START GLOBAL ITERATION #%lu, SEED %lu\r\n", run_iter, seed_run);

        for (uint8_t rb = FROM_RAMBLOCK; rb <= TOP_RAMBLOCK; ++rb)
        {
            *RAMBLOCK_REG = rb;
            printf("WRITING RAMBLOCK = %u\r\n", rb);
            uint32_t seed_rb = seed;
            patwrite(RAMBLOCK_FRAME, BLOCK_SIZE, &seed);
            errors += patcheck(RAMBLOCK_FRAME, BLOCK_SIZE, &seed_rb);
        }

        // RAMBLOCK_FRAME[0x342] = 0;      // make an error in the last ramblock we visited.

        for (uint8_t rb = FROM_RAMBLOCK; rb <= TOP_RAMBLOCK; ++rb)
        {
            *RAMBLOCK_REG = rb;
            printf("CHECKING RAMBLOCK = %u\r\n", rb);
            errors += patcheck(RAMBLOCK_FRAME, BLOCK_SIZE, &seed_run);
        }

        tot_errors += errors;
        printf("FIN GLOBAL ITERATION #%lu, ERRORS %lu, TOT ERRORS %lu\r\n", run_iter, errors, tot_errors);
        run_iter++;
    }


    printf("PROGRAM FINISHED.\r\n");
    return 0;
}
