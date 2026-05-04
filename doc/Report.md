# SoC系统芯片课程大作业报告

## 1. 项目概述

本项目基于现有 Cortex-M3 SoC 框架实现录音数据采集与存储。系统通过 I2S 接口接收 INMP441 数字麦克风的单声道 24bit PCM 数据，CPU 轮询读取样本并写入 SPI Flash，实现录音数据的可存储与可导出。

目标与指标如下：
- 采样率：16 kHz
- 声道：单声道（左声道）
- 位宽：24 bit PCM
- 录音时长：10 s ~ 30 s
- 存储方案：SPI Flash 顺序读写

## 2. 系统总体设计

### 2.1 架构概览

数据通路为：
I2S 麦克风 -> i2s_rx_core -> audio_fifo -> CPU 轮询 -> spi_flash 控制器 -> SPI Flash

SoC 内部通过 AHB/APB 总线连接新增外设：
- audio_fifo 外设（APB 扩展端口 12）
- spi_flash 外设（APB 扩展端口 13）

### 2.2 APB 地址映射

APB 基地址为 0x4000_0000，按 4 KB 页解码：
- audio_fifo：0x4000_C000
- spi_flash：0x4000_D000

## 3. 关键模块设计

### 3.1 i2s_rx_core

功能：从 I2S 串行数据中提取左声道 24bit PCM 样本。

要点：
- I2S 采样边沿：SCK 上升沿采样 SD
- WS=0 为左声道，WS=1 为右声道（右声道丢弃）
- 左声道 MSB 相对 WS 边沿延迟 1 个 SCK 周期
- 输出：sample_data[23:0] 与单周期 sample_valid

### 3.2 audio_fifo + audio_ctrl_apb

audio_fifo 为纯 FIFO，负责样本缓存；audio_ctrl_apb 提供 APB 寄存器与状态管理，并完成 sample_valid 去重（上升沿写入一次，避免重复入队）。

寄存器定义如下（基址 0x4000_C000）：
- 0x00 CTRL：bit0 fifo_en，bit1 fifo_clr
- 0x04 STATUS：empty/full/overflow/underflow/data_ready
- 0x08 DATA：读出样本（读即弹出）
- 0x0C FIFO_LEVEL：FIFO 深度计数

### 3.3 spi_flash_apb_ctrl

功能：提供 APB 可编程 SPI Flash 顺序读写控制。

寄存器定义如下（基址 0x4000_D000）：
- 0x00 START_ADDR：起始地址
- 0x04 BYTE_LEN：读写长度
- 0x08 CTRL：start_wr/start_rd/abort/clr_done
- 0x0C STATUS：busy/done/err/wdata_ready/rdata_valid/overflow/underflow
- 0x10 WDATA：写数据入口（低 24bit 有效）
- 0x14 RDATA：读数据出口
- 0x18 DEBUG_CNT：已处理字节计数

## 4. SoC 集成

### 4.1 顶层端口扩展

新增 I2S 与 SPI Flash 引脚：
- i2s_sck, i2s_ws, i2s_sd
- flash_cs_n, flash_sclk, flash_mosi, flash_miso

### 4.2 APB 扩展端口接入

- ext12 -> audio_ctrl_apb
- ext13 -> spi_flash_apb_ctrl

### 4.3 I2S 时钟生成

目标频率：pclk=50MHz，i2s_ws=16kHz，i2s_sck=1.024MHz。采用分频累加器生成 i2s_sck，使用 SCK 计数生成 i2s_ws，满足 i2s_sck:i2s_ws=64:1。

## 5. 软件流程（CPU 轮询）

最小闭环流程：
1) 配置 spi_flash 写任务（START_ADDR, BYTE_LEN, CTRL.start_wr）。
2) 轮询 audio_fifo.STATUS.data_ready 读取 DATA。
3) 轮询 spi_flash.STATUS.wdata_ready 写入 WDATA（低 24bit 有效）。
4) 轮询 spi_flash.STATUS.done，W1C 清除 done。
5) 读回流程类似，start_rd 后轮询 rdata_valid 读取 RDATA。

## 6. 验证与测试

### 6.1 SoC 仿真验证

使用 Phase5 SoC 级 testbench，I2S 端输入 16 个递增样本，SPI Flash 侧写入/读回进行比对。仿真结果 PASS：
- WS 半帧计数正确
- SPI 写入序列与 I2S 输入一致
- CPU 读回 SRAM 数据与输入一致

### 6.2 上板测试

I2S 与 SPI Flash 引脚连接如下：
- i2s_sck: PIN_AA15
- i2s_sd:  PIN_W13
- i2s_ws:  PIN_AB13
- flash_cs_n:  PIN_Y5
- flash_miso:  PIN_Y4
- flash_mosi:  PIN_Y3
- flash_sclk:  PIN_AA2

上板测试现象：
- I2S 采样写入内存正常
- SPI Flash 再次读回数据时读到 0
- 推测问题可能位于 Flash 读时序或读流程控制，仍需进一步定位

## 7. 当前进度与问题

已完成：
- 新增外设模块设计与验证
- SoC 集成与仿真验证
- SoC 系统级 testbench 与 Keil 工程

问题：
- FPGA 上板读回 SPI Flash 数据异常（读到 0）

## 8. 预计验收展示

- 展示 SoC 仿真验证 PASS
- 展示上板 I2S 采集样本并写入内存
- SPI 读回问题暂不展示，作为后续优化内容

## 9. 总结与后续计划

本项目完成了从 I2S 采样、FIFO 缓冲、APB 访问、SPI Flash 写入/读回的 SoC 闭环仿真验证，达成课程主线要求。后续将重点排查 FPGA 上板 SPI 读回异常，关注 Flash 读时序、信号完整性与控制状态机细节，完善完整链路的上板验证。