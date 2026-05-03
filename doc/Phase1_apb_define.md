# Phase1 APB新增外设定义文档（audio_fifo + spi_flash）

## 1. 文档目标与范围
- 本文档用于 Phase1 方案冻结，定义录音主线中 APB 新增外设的最小可实现方案。
- 仅覆盖基本功能闭环：
  - I2S路径提供样本到 `audio_fifo`
  - CPU 轮询 `audio_fifo` 读取有效样本
  - CPU 通过 APB 写入 `spi_flash` 控制器完成顺序存储
- 不包含进阶功能（WAV打包、ADPCM、DMA、多通道、复杂中断策略）。

## 2. 设计前提（冻结项）
- SoC APB 地址空间基址：`0x4000_0000`。
- APB 从设备按 4KB 页粒度解码（与现有 GPIO 映射风格一致）。
- 新增两类外设，地址冻结如下：
  - `audio_fifo`：`0x4000_C000`（扩展端口 12）
  - `spi_flash`：`0x4000_D000`（扩展端口 13）
- 音频数据格式：单声道左声道 24bit PCM。
- CPU 工作方式：轮询读取，不依赖中断作为主路径。

## 3. APB地址映射总表

| 外设 | 基地址 | 页大小 | APB扩展端口 | 说明 |
| --- | --- | --- | --- | --- |
| audio_fifo | 0x4000_C000 | 4KB | 12 | 音频FIFO状态与数据读口 |
| spi_flash | 0x4000_D000 | 4KB | 13 | SPI FLASH写控制与状态 |

说明：两个外设均使用 32bit APB 数据总线，寄存器 4 字节对齐。

## 4. audio_fifo 外设定义

### 4.1 功能定义（最小闭环）
- 接收上游音频样本写入（来自 i2s_rx_core 或其上层音频路径）。
- 向 CPU 提供：
  - FIFO 水位状态
  - 空/满/溢出标志
  - 样本读口（CPU 每次读出 1 个样本）
- CPU 通过轮询 `STATUS` 或 `FIFO_LEVEL` 判断是否可读，再读取 `DATA`。

### 4.2 寄存器映射
基址：`0x4000_C000`

| 偏移 | 寄存器名 | 属性 | 复位值 | 描述 |
| --- | --- | --- | --- | --- |
| 0x00 | CTRL | RW | 0x0000_0000 | 控制寄存器 |
| 0x04 | STATUS | RO/W1C | 0x0000_0001 | 状态寄存器 |
| 0x08 | DATA | RO | 0x0000_0000 | 样本读口 |
| 0x0C | FIFO_LEVEL | RO | 0x0000_0000 | FIFO当前深度 |

#### CTRL (0x00)
- bit[0] `fifo_en`：1=使能FIFO读写路径，0=关闭。
- bit[1] `fifo_clr`：写1触发清空FIFO（自清零）。
- bit[31:2]：保留，写0。

#### STATUS (0x04)
- bit[0] `empty`：FIFO空标志。
- bit[1] `full`：FIFO满标志。
- bit[2] `overflow`：写入溢出锁存标志；W1C 清除。
- bit[3] `underflow`：CPU 在空FIFO读DATA时置位；W1C 清除。
- bit[4] `data_ready`：`FIFO_LEVEL != 0` 时为1。
- bit[31:5]：保留。

#### DATA (0x08)
- bit[23:0] `sample_data`：24bit PCM样本（左对齐或右对齐在模块内固定，建议右对齐到 bit[23:0]）。
- bit[31:24]：读0。
- 读行为：
  - 当FIFO非空时，读操作弹出1个样本。
  - 当FIFO为空时，返回0，同时 `underflow` 置位。

#### FIFO_LEVEL (0x0C)
- bit[15:0] `level`：当前样本数。
- bit[31:16]：保留。

### 4.3 模块端口定义（建议）

```verilog
module audio_ctrl_apb #(
    parameter FIFO_DEPTH = 16
) (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    input  wire        sample_valid,
    input  wire [23:0] sample_data,

    output wire        fifo_empty,
    output wire        fifo_full,
    output wire [15:0] fifo_level
);
```

端口约束说明：
- APB 为单周期 ready（`pready=1'b1`），简化 Phase1 集成。
- `pslverr` 固定 0。
- `sample_valid/sample_data` 与 `pclk` 同时钟域（Phase1 假设, pclk分频得出了sample_valid/sample_data）；跨时钟问题在后续阶段处理。
- `sample_valid`控制fifo写入, 但是由于是`pclk`分频时钟相关信号, sample_valid会持续多个`pclk`周期, 此处需要处理, 避免重复写入fifo

## 5. spi_flash 外设定义

### 5.1 功能定义（Phase1 冻结）
- 提供 APB 可编程 SPI FLASH 读写控制通路。
- CPU 统一采用“配置-启动-轮询”的工作方式：
  - 写入流程：I2S 采样 -> CPU 读 `audio_fifo` -> CPU 写 `spi_flash` -> 完成整段录音写入。
  - 读取流程：CPU 分批次从 `spi_flash` 读取到片上内存（受内存容量限制）。
- 读/写均为顺序模式，Phase1 不做随机访问优化。
- 读/写任务相互独占：同一时刻只允许一个方向的任务进行。

### 5.2 寄存器映射
基址：`0x4000_D000`

| 偏移 | 寄存器名 | 属性 | 复位值 | 描述 |
| --- | --- | --- | --- | --- |
| 0x00 | START_ADDR | RW | 0x0000_0000 | Flash 起始地址（读/写共用） |
| 0x04 | BYTE_LEN | RW | 0x0000_0000 | 本次任务总字节数（读/写共用） |
| 0x08 | CTRL | RW | 0x0000_0000 | 控制寄存器 |
| 0x0C | STATUS | RO/W1C | 0x0000_0000 | 状态寄存器 |
| 0x10 | WDATA | WO | 0x0000_0000 | 写数据入口 |
| 0x14 | RDATA | RO | 0x0000_0000 | 读数据出口 |
| 0x18 | DEBUG_CNT | RO | 0x0000_0000 | 已处理字节计数 |

#### START_ADDR (0x00)
- bit[23:0] `start_addr`：目标 Flash 起始地址。
- bit[31:24]：保留。

#### BYTE_LEN (0x04)
- bit[23:0] `byte_len`：本次任务总字节数。
- bit[31:24]：保留。

#### CTRL (0x08)
- bit[0] `start_wr`：写1启动一次写任务（自清零）。
- bit[1] `start_rd`：写1启动一次读任务（自清零）。
- bit[2] `abort`：写1请求终止当前任务（自清零）。
- bit[3] `clr_done`：写1清除 done 状态（自清零）。
- bit[31:4]：保留。

#### STATUS (0x0C)
- bit[0] `busy`：控制器忙。
- bit[1] `done`：任务完成锁存；W1C 清除。
- bit[2] `err`：错误锁存（SPI超时/非法流程）；W1C 清除。
- bit[3] `wdata_ready`：可接受新的 `WDATA` 写入。
- bit[4] `rdata_valid`：`RDATA` 有效，可读取。
- bit[5] `overflow`：写入字节超过 `BYTE_LEN` 置位；W1C 清除。
- bit[6] `underflow`：读任务时 CPU 在无有效 `RDATA` 时读出，置位；W1C 清除。
- bit[31:7]：保留。

#### WDATA (0x10)
- bit[31:0] `wdata`：CPU 写入数据。
- 写行为：当 `wdata_ready=1` 时接受；否则忽略并置 `err`。
- 数据组织约束（冻结）：
  - CPU 将 24bit 音频样本按 32bit 对齐写入（低 24bit 有效，高 8bit 填0）。
  - `BYTE_LEN` 按实际写入字节统计（每样本按 4 字节计）。

#### RDATA (0x14)
- bit[31:0] `rdata`：CPU 读取数据。
- 读行为：当 `rdata_valid=1` 时返回有效数据并弹出 1 个字；否则返回 0 并置 `underflow`。

#### DEBUG_CNT (0x18)
- bit[23:0] `processed_bytes`：本次任务已处理字节计数（读/写共用）。
- bit[31:24]：保留。

### 5.3 模块端口定义（建议）

```verilog
module spi_flash_apb_ctrl (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    output reg         flash_cs_n,
    output reg         flash_sclk,
    output reg         flash_mosi,
    input  wire        flash_miso
);
```

端口约束说明：
- APB 侧同样采用 `pready=1'b1` 简化总线握手。
  - SPI 时序发生器、页写/顺序读状态机在模块内实现，Phase1 不暴露复杂配置寄存器。

## 6. APB数据流与软件轮询流程（冻结）

### 6.1 数据流
1. I2S 接收链路输出 `sample_valid/sample_data` 给 `audio_fifo`。
2. CPU 轮询 `audio_fifo.STATUS.data_ready`。
3. 若有数据：CPU 读取 `audio_fifo.DATA` 获取 24bit 样本。
4. CPU 轮询 `spi_flash.STATUS.wdata_ready`。
5. 若可写：CPU 将样本打包为 32bit 写入 `spi_flash.WDATA`。
6. 循环至达到目标样本数，最终轮询 `spi_flash.STATUS.done`。
7. 录音完成后，CPU 分批次启动 `spi_flash` 读任务，将数据读入片上内存缓冲区。
8. 每读取一段数据，在 Keil 调试模式下进入断点，手动 SAVE 当前内存窗口到本地文件。

### 6.2 CPU最小伪代码

```c
// 1) 配置 flash 写任务
WR32(SPI_BASE + START_ADDR, rec_start_addr);
WR32(SPI_BASE + BYTE_LEN,   total_samples * 4);
WR32(SPI_BASE + CTRL,       0x1); // start_wr

// 2) 轮询搬运
for (i = 0; i < total_samples; i++) {
    while ((RD32(AUD_BASE + STATUS) & (1u << 4)) == 0) {
        ;
    }
    sample = RD32(AUD_BASE + DATA) & 0x00FFFFFF;

    while ((RD32(SPI_BASE + STATUS) & (1u << 3)) == 0) {
        ;
    }
    WR32(SPI_BASE + WDATA, sample);
}

// 3) 等待完成
while ((RD32(SPI_BASE + STATUS) & (1u << 1)) == 0) {
    ;
}
WR32(SPI_BASE + STATUS, (1u << 1)); // W1C done

// 4) 分批读取并导出（示例）
for (offset = 0; offset < total_samples * 4; offset += chunk_bytes) {
  // chunk_bytes 受片上内存容量限制
  WR32(SPI_BASE + START_ADDR, rec_start_addr + offset);
  WR32(SPI_BASE + BYTE_LEN,   chunk_bytes);
  WR32(SPI_BASE + CTRL,       0x2); // start_rd

  for (i = 0; i < chunk_bytes / 4; i++) {
    while ((RD32(SPI_BASE + STATUS) & (1u << 4)) == 0) {
      ;
    }
    buf[i] = RD32(SPI_BASE + RDATA);
  }

  while ((RD32(SPI_BASE + STATUS) & (1u << 1)) == 0) {
    ;
  }
  WR32(SPI_BASE + STATUS, (1u << 1)); // W1C done

  // Keil 调试模式下在此处断点，手动 SAVE buf[]
}
```

## 7. 与后续阶段接口约束
- 本文档冻结以下接口语义，后续 RTL 与软件需严格保持：
  - `audio_fifo.DATA`：读即弹出一个样本
  - `spi_flash.WDATA`：写入数据入口，受 `wdata_ready` 节流
  - `spi_flash.RDATA`：读出数据入口，受 `rdata_valid` 节流
  - 状态位 `done/err/overflow/underflow` 采用 W1C 清除
- 后续可扩展项（不影响本冻结基线）：
  - 增加中断寄存器 `INT_EN/INT_ST`
  - 增加 DMA 模式
  - 增加 Flash 读回校验和擦除策略优化

## 8. Phase1验收检查项
- 地址映射固定：`0x4000_C000` / `0x4000_D000`。
- 软件可通过 APB 访问全部冻结寄存器。
- 轮询流程可跑通“FIFO取样本 -> Flash写入”的最小逻辑闭环。
- 文档可直接作为 `audio_fifo_apb` 与 `spi_flash_apb_ctrl` RTL 设计输入。
