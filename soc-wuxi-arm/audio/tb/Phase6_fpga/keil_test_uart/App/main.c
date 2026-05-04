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

#define SAMPLE_COUNT    16u
#define PATTERN_SYNC0   0x55AA55AAu
#define PATTERN_SYNC1   0xAA55AA55u
#define PATTERN_LEN     64u

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

static void uart_send_buffer(uint32_t base, const uint8_t *data, uint32_t len)
{
    uint32_t i;

    for (i = 0; i < len; i++) {
        uart_send_byte(base, data[i]);
    }
}

static void uart_send_u32_le(uint32_t base, uint32_t value)
{
    uint8_t bytes[4];

    bytes[0] = (uint8_t)(value & 0xFFu);
    bytes[1] = (uint8_t)((value >> 8) & 0xFFu);
    bytes[2] = (uint8_t)((value >> 16) & 0xFFu);
    bytes[3] = (uint8_t)((value >> 24) & 0xFFu);

    uart_send_buffer(base, bytes, 4u);
}

static uint32_t uart_calc_checksum(uint32_t seed, uint32_t value)
{
    return seed ^ value;
}

static void uart_test(void)
{
    static const uint8_t msg[] = "UART1 CMSDK test\r\n";

    uart_init(UART1_BASE_RTL, UART_PCLK_HZ, UART_BAUDRATE);
    uart_send_buffer(UART1_BASE_RTL, msg, (uint32_t)sizeof(msg) - 1u);
    uart_send_u32_le(UART1_BASE_RTL, 0x12345678u);
    uart_send_buffer(UART1_BASE_RTL, (const uint8_t *)"\r\n", 2u);
}

static void uart_pattern_test(void)
{
    uint32_t i;
    uint32_t checksum = 0u;

    uart_send_u32_le(UART1_BASE_RTL, PATTERN_SYNC0);
    uart_send_u32_le(UART1_BASE_RTL, PATTERN_SYNC1);
    uart_send_u32_le(UART1_BASE_RTL, PATTERN_LEN);

    for (i = 0; i < PATTERN_LEN; i++) {
        uint8_t b0 = (uint8_t)i;
        uint8_t b1 = (uint8_t)(i ^ 0xFFu);

        uart_send_byte(UART1_BASE_RTL, b0);
        uart_send_byte(UART1_BASE_RTL, b1);
        checksum = uart_calc_checksum(checksum, (uint32_t)b0 | ((uint32_t)b1 << 8));
    }

    uart_send_u32_le(UART1_BASE_RTL, checksum);
}

int main(void)
{
    uint32_t sample;
    uint32_t i;
    volatile uint32_t *rd_buf = (uint32_t *)RD_BUF_ADDR;

    //uart_test();
    //uart_pattern_test();
    uart_init(UART1_BASE_RTL, UART_PCLK_HZ, UART_BAUDRATE);

    // Enable FIFO path
    wr32(AUD_CTRL, 0x1u);

    // Polling data move
    for (i = 0; i < SAMPLE_COUNT; i++) {
        uint8_t b0;
        uint8_t b1;
        uint8_t b2;
        uint8_t b3;

        while ((rd32(AUD_STATUS) & (1u << 4)) == 0u) {
        }
        sample = rd32(AUD_DATA);
        rd_buf[i] = sample;

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
