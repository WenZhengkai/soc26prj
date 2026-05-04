#include <stdint.h>


#define AUD_BASE        0x4000C000u
#define SPI_BASE        0x4000D000u

#define AUD_CTRL        (AUD_BASE + 0x00u)
#define AUD_STATUS      (AUD_BASE + 0x04u)
#define AUD_DATA        (AUD_BASE + 0x08u)

#define SPI_START_ADDR  (SPI_BASE + 0x00u)
#define SPI_BYTE_LEN    (SPI_BASE + 0x04u)
#define SPI_CTRL        (SPI_BASE + 0x08u)
#define SPI_STATUS      (SPI_BASE + 0x0Cu)
#define SPI_WDATA       (SPI_BASE + 0x10u)
#define SPI_RDATA       (SPI_BASE + 0x14u)

#define SAMPLE_COUNT    16u
#define START_ADDR      0x000000u

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

    // Configure SPI write job
    wr32(SPI_START_ADDR, START_ADDR);
    wr32(SPI_BYTE_LEN, SAMPLE_COUNT * 4u);
    wr32(SPI_CTRL, 0x1u); // start_wr

    // Polling data move
    for (i = 0; i < SAMPLE_COUNT; i++) {
        while ((rd32(AUD_STATUS) & (1u << 4)) == 0u) {
        }
        sample = rd32(AUD_DATA) & 0x00FFFFFFu;
				//rd32(AUD_DATA);
				//sample = 0x68686800 + i ;
				rd_buf[i] = sample;

        while ((rd32(SPI_STATUS) & (1u << 3)) == 0u) {
        }
        wr32(SPI_WDATA, sample);
    }

    // Wait for completion and clear done
    while ((rd32(SPI_STATUS) & (1u << 1)) == 0u) {
    }
    wr32(SPI_STATUS, (1u << 1));

    // Configure SPI read job
    wr32(SPI_START_ADDR, START_ADDR);
    wr32(SPI_BYTE_LEN, SAMPLE_COUNT * 4u);
    wr32(SPI_CTRL, 0x2u); // start_rd

    for (i = 0; i < SAMPLE_COUNT; i++) {
        while ((rd32(SPI_STATUS) & (1u << 4)) == 0u) {
        }
        rd_buf[i] = rd32(SPI_RDATA);
    }

    while ((rd32(SPI_STATUS) & (1u << 1)) == 0u) {
    }
    wr32(SPI_STATUS, (1u << 1));

    wr32(DONE_FLAG_ADDR, 0xA5A5A5A5u);

    while (1) {
    }

    return 0;
}
