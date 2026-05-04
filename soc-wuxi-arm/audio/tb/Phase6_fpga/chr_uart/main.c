#include <stdint.h>
#include "soc.h"
#include "usart.h"

/* 当前回显测试同时打开两路 UART，避免板级接线端口判断错误。 */
#define ECHO_BAUDRATE   (115200UL)

/* 查询指定 UART 是否已经收到数据。 */
static int uart_rx_ready(uint32_t base_addr)
{
    volatile uint8_t *lsr = (uint8_t *)(base_addr + RD_LSR);

    return ((*lsr & LSR_RX_FIFO_HAS_DATA) != 0U);
}

/* 以阻塞方式发送一个字节，确保每个回显字节都真正写入发送 FIFO。 */
static void uart_send_byte_blocking(uint32_t base_addr, uint8_t data)
{
    volatile uint8_t *thr = (uint8_t *)(base_addr + WR_THR);
    volatile uint8_t *lsr = (uint8_t *)(base_addr + RD_LSR);

    while (((*lsr) & LSR_TX_FIFO_EMPTY) == 0U) {
        /* 等待发送 FIFO 空出位置。 */
    }

    *thr = data;
}

/* 发送字符串时统一走阻塞发送，避免启动信息丢字节。 */
static void uart_send_string_blocking(uint32_t base_addr, const char *str)
{
    if (str == 0) {
        return;
    }

    while (*str != '\0') {
        uart_send_byte_blocking(base_addr, (uint8_t)(*str));
        str++;
    }
}

/* 对单路 UART 执行一次轮询回显。 */
static void uart_echo_once(uint32_t base_addr)
{
    uint8_t rx_data;

    if (!uart_rx_ready(base_addr)) {
        return;
    }

    rx_data = uart_receive_byte(base_addr);
    uart_send_byte_blocking(base_addr, rx_data);
}

/* 当前纯回显程序不使用 UART0 发送中断，这里提供空实现满足链接。 */
void UART0_TX_DATA_Handler(void)
{
    /* 保留空函数，避免 usart.c 中的中断回调引用导致链接失败。 */
}

int main(void)
{
    /* 同时初始化两路 UART，便于直接验证板上的两组串口引脚。 */
    uart_init(UART0_BASE, SYSTEM_CLOCK, ECHO_BAUDRATE);
    uart_init(UART1_BASE, SYSTEM_CLOCK, ECHO_BAUDRATE);

    uart_send_string_blocking(UART0_BASE, "UART0 echo ready.\r\n");
    uart_send_string_blocking(UART1_BASE, "UART1 echo ready.\r\n");

    while (1) {
        /* 哪一路收到数据，就从同一路原样回发。 */
        uart_echo_once(UART0_BASE);
        uart_echo_once(UART1_BASE);
    }
}
