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

#define SAMPLE_COUNT    16u
#define START_ADDR      0x000000u

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

    // Enable FIFO path
    wr32(AUD_CTRL, 0x1u);

    // Configure SPI write job
    wr32(SPI_START_ADDR, START_ADDR);
    wr32(SPI_BYTE_LEN, SAMPLE_COUNT * 4u);
    wr32(SPI_CTRL, 0x1u);

    // Polling data move
    for (i = 0; i < SAMPLE_COUNT; i++) {
        while ((rd32(AUD_STATUS) & (1u << 4)) == 0u) {
        }
        sample = rd32(AUD_DATA) & 0x00FFFFFFu;

        while ((rd32(SPI_STATUS) & (1u << 3)) == 0u) {
        }
        wr32(SPI_WDATA, sample);
    }

    // Wait for completion and clear done
    while ((rd32(SPI_STATUS) & (1u << 1)) == 0u) {
    }
    wr32(SPI_STATUS, (1u << 1));

    while (1) {
    }

    return 0;
}
