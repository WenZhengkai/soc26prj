#include <stdint.h>


#define AUD_BASE        0x4000C000u

#define AUD_CTRL        (AUD_BASE + 0x00u)
#define AUD_STATUS      (AUD_BASE + 0x04u)
#define AUD_DATA        (AUD_BASE + 0x08u)


#define SAMPLE_COUNT    16u


#define RD_BUF_ADDR     0x0000C000u
#define DONE_FLAG_ADDR  0x0000BFFCu

static inline void wr32(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t rd32(uint32_t addr)
{
    return *(volatile uint32_t *)addr;
}


int main(void)
{
    uint32_t sample;
    uint32_t i;
    volatile uint32_t *rd_buf = (uint32_t *)RD_BUF_ADDR;

    // Enable FIFO path
    wr32(AUD_CTRL, 0x1u);

    // Polling data move
    for (i = 0; i < SAMPLE_COUNT; i++) {
        while ((rd32(AUD_STATUS) & (1u << 4)) == 0u) {
        }
        sample = rd32(AUD_DATA) & 0x00FFFFFFu;
        rd_buf[i] = sample;
    }

    wr32(DONE_FLAG_ADDR, 0xA5A5A5A5u);

    while (1) {
    }

    return 0;
}
