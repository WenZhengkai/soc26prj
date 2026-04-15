
#include <stdio.h>
#include <stdint.h>

#include "nvic.h"
#include "drv_usart.h"
#include "delay.h"
#include "usart.h"
#include "soc.h"
#include "gpio.h"

/* Cortex System Control register address */
#define SCB_SysCtrl              ((uint32_t)0xE000ED10)
//sleep bit mask
#define SysCtrl_SLEEPDEEP_Set    ((uint32_t)0x00000004)

void RTC_IRQHandler(void)
{
	 int* addr;
	  int a;
	 addr = (int*)0x4001200c;
	 a = *addr;
	 addr = (int*)0x40050000;
	 *addr = a;
	
	 addr = (int*)0x40012000;
	 *addr = 0x5;
}

int main(void)
{
  int* addr; 
	char ch[16]="hello world!";
	int i=0;
	int j;
	int full;

	
  addr = (int*)0x0009000;
	*addr = 0xabcdabcd;
	
	
	// 以下放你们的代码。。。。。。
	
	addr = (int*)0x0009004;
	*addr = 0x5a5a5a5a;


    // 1. 定义 GPIO 寄存器指针
    // 0x40004000: 基地址
    // 0x40004004: 方向寄存器 (Offset 1 * 4字节)
    // 0x40004000: 数据寄存器 (Offset 0)
    
    volatile uint32_t *gpio_dr  = (uint32_t *)0x40004000;
    volatile uint32_t *gpio_ddr = (uint32_t *)0x40004004;

    // 2. 配置为输出：把低8位设为1
    *gpio_ddr = 0xFF;

    // 3. 实现翻转 (Toggle)
    while(1) {
        *gpio_dr = 0xFF; // 全高
        for(int i=0; i<10; i++); // 简易延时
        
        *gpio_dr = 0x00; // 全低
        for(int i=0; i<10; i++);
    }


    return 0;
}


























/*int main(void)
{
	u8 len;
	u32 timex;

	//延时初始化 systick初始化
	delay_init();

	//uart初始化
	usart_handle_t p_uart;
	p_uart = uart_init(UART0, NULL, NULL);

	//FIFO 波特率9600、19200、115200 异步发送  无校验  1bits停止位  8bits数据位
	uart_config(p_uart, SYSTEM_CLOCK, 115200, USART_MODE_ASYNCHRONOUS, USART_PARITY_NONE, USART_STOP_BITS_1, USART_DATA_BITS_8);

	//FIFO 波特率115200 异步发送  无校验  1bits停止位  8bits数据位
	//uart_config(p_uart, SYSTEM_CLOCK, 115200, USART_MODE_ASYNCHRONOUS, USART_PARITY_NONE, USART_STOP_BITS_1, USART_DATA_BITS_8);

	//FIFO 波特率9600、115200 异步发送  奇校验  1bits停止位  8bits数据位
	//uart_config(p_uart, SYSTEM_CLOCK, 115200, USART_MODE_ASYNCHRONOUS, USART_PARITY_ODD, USART_STOP_BITS_1, USART_DATA_BITS_8);

	//FIFO 波特率9600、115200 异步发送  偶校验  1bits停止位  8bits数据位
	//uart_config(p_uart, SYSTEM_CLOCK, 115200, USART_MODE_ASYNCHRONOUS, USART_PARITY_EVEN, USART_STOP_BITS_1, USART_DATA_BITS_8);

	//FIFO 波特率115200 异步发送  无校验  1bits停止位  5、6、7bits数据位
	//uart_config(p_uart, SYSTEM_CLOCK, 115200, USART_MODE_ASYNCHRONOUS, USART_PARITY_NONE, USART_STOP_BITS_1, USART_DATA_BITS_5);

	//FIFO 波特率115200 异步发送  无校验  1.5、2bits停止位  8bits数据位
	//uart_config(p_uart, SYSTEM_CLOCK, 115200, USART_MODE_ASYNCHRONOUS, USART_PARITY_NONE, USART_STOP_BITS_1_5, USART_DATA_BITS_8);

	//led gpio初始化
	//gpio_init();

	uart_nvic_config();

	while(1){

		//led_blink();
		//led_flow();

		//uart_read(p_uart, rx_data, sizeof(rx_data));
		//uart_send(p_uart, tx_data, sizeof(tx_data));

		if(UART_RX_STA & 0x8000){
			len = (UART_RX_STA & 0x3FFF);
			printf("\r\n您发送的消息为:\r\n");
			for(u16 t = 0; t < len; t ++){
				//uart_send_byte(p_uart, UART_RX_BUF[t]);
				UART_SendData(UART0, UART_RX_BUF[t]);
			}
			printf("\r\n");
			UART_RX_STA = 0;
		}
		else{
			timex ++;
			if(timex % 200 == 0)
				printf("请输入数据，以回车结束\r\n");
			//uart_send(p_uart, tx_data, sizeof(tx_data));
			//u8 t = sizeof(tx1_data);
			//for(u8 i = 0; i < t; i ++){
				//uint8_t x = tx1_data[t];
				//UART_SendData(UART0, tx1_data[t]);
			//}
			//printf("abcdefghijklmnopqrstuvwxyz");
			delay_ms(10);
		}
	}


//    static uint32_t i = 0;
//
//	x = 8;
//	while(1){

//		i ++;
//
////		delay_ms(2);
//
////		count ++;
//
//	}

}
*/

