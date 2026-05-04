#define _USART_C_

#include <stdint.h>
#include "usart.h"

/* 保留原工程中的全局状态定义，避免其它文件引用时出现链接问题。 */
static volatile uint8_t rx_async_flag = 0;
static volatile uint8_t tx_async_flag = 0;
static volatile uint8_t rx_trigger_flag = 0;

/* 简单忙等，用于发送 FIFO 状态轮询时拉开一点访问间隔。 */
static void my_delay(void)
{
    volatile uint32_t i;

    for (i = 0U; i < 1000U; i++) {
        __NOP();
    }
}

void uart_init(uint32_t base_addr, uint32_t clk_freq, uint32_t baud_rate)
{
    volatile uint8_t *lcr = (uint8_t *)(base_addr + WR_LCR);
    volatile uint8_t *dll = (uint8_t *)(base_addr + WR_DLL);
    volatile uint8_t *dlm = (uint8_t *)(base_addr + WR_DLM);
    volatile uint8_t *fcr = (uint8_t *)(base_addr + WR_FCR);
    uint16_t divisor;

    /* 先写分频寄存器，再回到正常数据格式寄存器页。 */
    divisor = (uint16_t)(clk_freq / baud_rate) - 1U;
    *lcr = LCR_DLAB;
    *dll = (uint8_t)(divisor & 0xFFU);
    *dlm = (uint8_t)(divisor >> 8);

    /* 配置成标准 8N1：8 位数据、1 位停止位、无校验位。 */
    *lcr = LCR_DATA_BITS_8;

    /* 使能并清空收发 FIFO，接收触发深度设为 1 字节。 */
    *fcr = FCR_RX_FIFO_CLR | FCR_TX_FIFO_CLR | FCR_TRIGGER_1;
}

void uart_send_first_byte(uint32_t base_addr, uint8_t data)
{
    volatile uint8_t *thr = (uint8_t *)(base_addr + WR_THR);
    volatile uint8_t *lsr = (uint8_t *)(base_addr + RD_LSR);

    while (((*lsr) & LSR_TX_FIFO_EMPTY) == 0U) {
        my_delay();
    }

    *thr = data;
}

void uart_send_normal_byte(uint32_t base_addr, uint8_t data)
{
    volatile uint8_t *thr = (uint8_t *)(base_addr + WR_THR);

    *thr = data;
}

void uart_send_string(uint32_t base_addr, const char *str)
{
    if (str == 0) {
        return;
    }

    while (*str != '\0') {
        uart_send_first_byte(base_addr, (uint8_t)(*str));
        str++;
    }
}

uint8_t uart_receive_byte(uint32_t base_addr)
{
    volatile uint8_t *rbr = (uint8_t *)(base_addr + RD_RBR);
    volatile uint8_t *lsr = (uint8_t *)(base_addr + RD_LSR);

    while (((*lsr) & LSR_RX_FIFO_HAS_DATA) == 0U) {
        /* 等待接收 FIFO 中出现新数据。 */
    }

    return *rbr;
}

int uart_receive_string(uint32_t base_addr, char *buffer, uint32_t max_len)
{
    uint32_t count;
    char rx_char;

    if ((buffer == 0) || (max_len == 0U)) {
        return -1;
    }

    count = 0U;
    while (count < (max_len - 1U)) {
        rx_char = (char)uart_receive_byte(base_addr);
        if (rx_char == '\n') {
            break;
        }

        buffer[count] = rx_char;
        count++;
    }

    buffer[count] = '\0';
    return (int)count;
}

void uart_set_interrupt_enable(uint32_t base_addr, uint8_t int_mask, uint8_t enable)
{
    volatile uint8_t *ier = (uint8_t *)(base_addr + WR_IER);
    uint8_t current_ier;

    current_ier = *ier;

    if (enable != 0U) {
        current_ier |= int_mask;
    } else {
        current_ier &= (uint8_t)(~int_mask);
    }

    *ier = current_ier;
}

void uart_clear_interrupt_flag(uint32_t base_addr)
{
    volatile uint8_t *ier = (uint8_t *)(base_addr + WR_IER);

    *ier = (uint8_t)(*ier | (1U << 3));
}

void UART0_Handler(void)
{
    volatile uint8_t *ier = (uint8_t *)(UART0_BASE + WR_IER);
    volatile uint8_t *iir = (uint8_t *)(UART0_BASE + RD_IIR);
    uint8_t iir_val;
    uint8_t int_type;

    iir_val = *iir;
    if ((iir_val & IIR_INT_PENDING) != 0U) {
        return;
    }

    int_type = (uint8_t)(iir_val & IIR_INT_TYPE_MASK);
    if (int_type == IIR_INT_TYPE_TX_EMPTY) {
        UART0_TX_DATA_Handler();
    }

    *ier = (uint8_t)(*ier & (uint8_t)(~IER_TX_EMPTY_EN));

    /* 保留原有状态变量，避免编译器将其完全优化掉。 */
    if ((rx_async_flag | tx_async_flag | rx_trigger_flag) != 0U) {
        rx_async_flag = 0U;
        tx_async_flag = 0U;
        rx_trigger_flag = 0U;
    }
}
