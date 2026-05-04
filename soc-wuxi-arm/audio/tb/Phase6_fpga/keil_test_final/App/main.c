#include <stdint.h>


#define AUD_BASE        0x4000C000u

#define AUD_CTRL        (AUD_BASE + 0x00u)
#define AUD_STATUS      (AUD_BASE + 0x04u)
#define AUD_DATA        (AUD_BASE + 0x08u)

// CMSDK APB UART (RTL UART1 is mapped to APB port 5 -> 0x40005000)
#define UART1_BASE_RTL  0x40005000u

#define UART_DR         0x00u
#define UART_STAT       0x04u
#define UART_CTRL       0x08u
#define UART_INTCLR     0x0Cu
#define UART_BAUDDIV    0x10u

#define UART_STAT_TX_FULL   (1u << 0)
#define UART_CTRL_TX_EN     (1u << 0)

#define UART_PCLK_HZ    50000000u
#define UART_BAUDRATE   115200u

#define SAMPLE_RATE_HZ  16000u
#define RECORD_SECONDS  10u
#define USE_TEST_SAMPLES 0u
#define TEST_SAMPLE_COUNT 16u

#define DONE_FLAG_ADDR  0x0000BFFCu

static inline void wr32(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t rd32(uint32_t addr)
{
    return *(volatile uint32_t *)addr;
}

static void uart_init(uint32_t base, uint32_t pclk_hz, uint32_t baudrate)
{
    uint32_t baud_div = (pclk_hz + (baudrate / 2u)) / baudrate;

    if (baud_div < 16u) {
        baud_div = 16u;
    }

    wr32(base + UART_BAUDDIV, baud_div);
    wr32(base + UART_INTCLR, 0x0Fu);
    wr32(base + UART_CTRL, UART_CTRL_TX_EN);
}

static void uart_send_byte(uint32_t base, uint8_t data)
{
    while ((rd32(base + UART_STAT) & UART_STAT_TX_FULL) != 0u) {
    }
    wr32(base + UART_DR, data);
}

static uint32_t get_sample_count(void)
{
    if (USE_TEST_SAMPLES != 0u) {
        return TEST_SAMPLE_COUNT;
    }

    return RECORD_SECONDS * SAMPLE_RATE_HZ;
}

int main(void)
{
    uint32_t sample;
    uint32_t i;
    uint32_t sample_count = get_sample_count();

    uart_init(UART1_BASE_RTL, UART_PCLK_HZ, UART_BAUDRATE);

    // Enable FIFO path
    wr32(AUD_CTRL, 0x1u);

    // Polling data move
    for (i = 0; i < sample_count; i++) {
        uint8_t b0;
        uint8_t b1;
        uint8_t b2;
        uint8_t b3;

        while ((rd32(AUD_STATUS) & (1u << 4)) == 0u) {
        }
        sample = rd32(AUD_DATA);
        b0 = (uint8_t)(sample & 0xFFu);
        b1 = (uint8_t)((sample >> 8) & 0xFFu);
        b2 = (uint8_t)((sample >> 16) & 0xFFu);
        b3 = (uint8_t)((sample >> 24) & 0xFFu);

        uart_send_byte(UART1_BASE_RTL, b0);
        uart_send_byte(UART1_BASE_RTL, b1);
        uart_send_byte(UART1_BASE_RTL, b2);
        uart_send_byte(UART1_BASE_RTL, b3);
    }

    wr32(DONE_FLAG_ADDR, 0xA5A5A5A5u);

    while (1) {
    }

    return 0;
}
