# Phase4 设计文档：spi_flash_apb_ctrl

## 1. 文档目的与范围

本文档用于阶段4实现输入，定义 `spi_flash_apb_ctrl` 的模块级设计规格，供后续 RTL 编写与模块级 testbench 设计使用。

范围：

- APB 从设备寄存器语义与读写行为
- SPI Flash 访问时序、命令序列与状态处理
- 与 SoC APB 子系统与顶层引脚的集成约束

不包含：

- 验证计划与测试向量
- DMA 与中断扩展
- 复杂随机读写与缓存优化

设计基线与约束来源：

- `doc/Phase1_apb_define.md`（寄存器语义基线，必须兼容）
- `soc-wuxi-arm/arm-soc/top.v`（APB 扩展端口 13 接入）
- 工程规划文档（阶段4目标与最小闭环要求）

---

## 2. 阶段定位与兼容性约束

当前阶段：**阶段4：存储通路最小闭环开发**。

强制约束：

1. 寄存器地址与字段语义必须与 Phase1 冻结一致。
2. APB 侧 `pready=1'b1`，`pslverr=1'b0`，保持单周期就绪风格。
3. CPU 采用“配置-启动-轮询”流程，硬件不依赖中断。
4. 数据通路只支持顺序读写，不包含随机读写与 DMA。
5. 地址映射固定为 `0x4000_D000`，APB 扩展端口 13。

---

## 3. SoC 集成上下文

### 3.1 APB 地址页与扩展端口

- APB 从设备按 `PADDR[15:12]` 做 4KB 页解码。
- `spi_flash_apb_ctrl` 连接 APB 扩展端口 13。
- 基地址：`0x4000_D000`。

### 3.2 顶层连接约束

`top.v` 中已预留 SPI Flash 引脚：

- `flash_cs_n`
- `flash_sclk`
- `flash_mosi`
- `flash_miso`

`spi_flash_apb_ctrl` 需直接驱动上述引脚，且与 `cmsdk_apb_subsystem` 的 ext13 连接保持一致。

---

## 4. SPI Flash 协议假设与目标器件

### 4.1 目标器件

- Winbond W25Q64 系列（25Q64JY），3.3V SPI Flash。
- 支持最高 104MHz SPI SCLK，满足 50MHz SoC PCLK 环境。

### 4.2 SPI 模式

- 采用标准 SPI 模式 0：`CPOL=0`，`CPHA=0`。
- 数据在 SCLK 上升沿采样，下降沿更新。

### 4.3 地址宽度

- 采用 24bit 地址（`A23:A0`）。
- 容量覆盖 64Mbit（8MB）空间。

### 4.4 SCLK 产生策略

- `flash_sclk` 由 `pclk` 分频生成。
- 采用参数化分频 `SCLK_DIV`（偶数，>=2）。
- 默认 `SCLK_DIV=2`，即 `SCLK = PCLK/2 = 25MHz`（保守安全）。

---

## 5. 模块端口定义（冻结）

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

---

## 6. APB 从设备策略

- `pready = 1'b1`（恒定单周期就绪）。
- `pslverr = 1'b0`（不返回 APB 错误）。
- 访问命中：
  - 写：`wr_hit = psel & penable & pwrite`
  - 读：`rd_hit = psel & penable & ~pwrite`

未定义地址读取返回 `32'h0000_0000`。

---

## 7. 寄存器映射（必须兼容 Phase1）

基地址：`0x4000_D000`

| 偏移 | 寄存器名 | 属性 | 复位值 | 描述 |
| --- | --- | --- | --- | --- |
| 0x00 | START_ADDR | RW | 0x0000_0000 | Flash 起始地址（读/写共用） |
| 0x04 | BYTE_LEN | RW | 0x0000_0000 | 本次任务总字节数（读/写共用） |
| 0x08 | CTRL | RW | 0x0000_0000 | 控制寄存器 |
| 0x0C | STATUS | RO/W1C | 0x0000_0000 | 状态寄存器 |
| 0x10 | WDATA | WO | 0x0000_0000 | 写数据入口 |
| 0x14 | RDATA | RO | 0x0000_0000 | 读数据出口 |
| 0x18 | DEBUG_CNT | RO | 0x0000_0000 | 已处理字节计数 |

### 7.1 START_ADDR (0x00)

- bit[23:0] `start_addr`：起始地址。
- bit[31:24]：保留，写 0。

### 7.2 BYTE_LEN (0x04)

- bit[23:0] `byte_len`：本次任务总字节数。
- bit[31:24]：保留，写 0。

约束：

- `BYTE_LEN` 必须是 4 的倍数。
- 否则在 `start_wr/start_rd` 触发时置位 `err`。

### 7.3 CTRL (0x08)

- bit[0] `start_wr`：写 1 启动一次写任务（自清零）。
- bit[1] `start_rd`：写 1 启动一次读任务（自清零）。
- bit[2] `abort`：写 1 请求终止当前任务（自清零）。
- bit[3] `clr_done`：写 1 清除 done（自清零）。
- bit[31:4]：保留。

同一时刻禁止同时置位 `start_wr` 与 `start_rd`；若发生，硬件置 `err`。

### 7.4 STATUS (0x0C)

- bit[0] `busy`：控制器忙。
- bit[1] `done`：任务完成锁存，W1C 清除。
- bit[2] `err`：错误锁存（非法流程/超时），W1C 清除。
- bit[3] `wdata_ready`：可接受新的 `WDATA` 写入。
- bit[4] `rdata_valid`：`RDATA` 有效，可读取。
- bit[5] `overflow`：写入字节超过 `BYTE_LEN`，W1C 清除。
- bit[6] `underflow`：读任务时 CPU 在无有效 `RDATA` 时读取，W1C 清除。
- bit[31:7]：保留。

### 7.5 WDATA (0x10)

- bit[31:0] `wdata`：CPU 写入数据。
- 写行为：
  - `wdata_ready=1` 时接收；否则忽略并置 `err`。
- 数据组织：
  - CPU 将 24bit 样本右对齐写入低 24bit，高 8bit 填 0。
  - 计数按 4 字节累计。

### 7.6 RDATA (0x14)

- bit[31:0] `rdata`：CPU 读取数据。
- 读行为：
  - `rdata_valid=1` 返回有效数据并弹出。
  - 否则返回 0 并置位 `underflow`。

### 7.7 DEBUG_CNT (0x18)

- bit[23:0] `processed_bytes`：本次任务已处理字节计数。
- bit[31:24]：保留。

---

## 8. 操作流程与软件语义

### 8.1 写任务流程（CPU 轮询）

1. `START_ADDR` 写入起始地址。
2. `BYTE_LEN` 写入目标字节数（4 字节对齐）。
3. `CTRL.start_wr=1` 启动写任务。
4. 轮询 `STATUS.wdata_ready`，为 1 时写入 `WDATA`。
5. 重复写入直到 `DEBUG_CNT == BYTE_LEN`。
6. 轮询 `STATUS.done`，然后 W1C 清除。

### 8.2 读任务流程（CPU 轮询）

1. `START_ADDR` 写入起始地址。
2. `BYTE_LEN` 写入目标字节数（4 字节对齐）。
3. `CTRL.start_rd=1` 启动读任务。
4. 轮询 `STATUS.rdata_valid`，为 1 时读取 `RDATA`。
5. 重复读取直到 `DEBUG_CNT == BYTE_LEN`。
6. 轮询 `STATUS.done`，然后 W1C 清除。

---

## 9. SPI 命令序列与状态机

### 9.1 采用的最小指令集

- `0x06` WREN（Write Enable）
- `0x04` WRDI（Write Disable，可选）
- `0x05` RDSR（Read Status Register）
- `0x02` PP（Page Program，最多 256 字节）
- `0x03` READ（Read Data）
- `0x20` SE（4KB Sector Erase）

### 9.2 写任务内部流程

在 `start_wr` 触发后：

1. 若 `AUTO_ERASE=1`：遍历覆盖范围的 4KB 扇区，依次发出 `SE` 并等待 WIP 清零。
2. 发出 `WREN`。
3. 执行 `PP`：发送 `0x02 + 24bit 地址`，随后写入数据字节流。
4. 每写满 256 字节或达到 `BYTE_LEN`，等待 WIP 清零，再进入下一页。
5. 完成后置位 `done`，清 `busy`。

约束：

- `WDATA` 以 32bit 为单位输入，每次拆分为 4 字节按顺序写入。
- 写跨页时自动换页，地址递增。

### 9.3 读任务内部流程

在 `start_rd` 触发后：

1. 发出 `READ (0x03)` + 24bit 地址。
2. 连续读出字节流，打包为 32bit `RDATA`。
3. `RDATA` 每 4 字节产生一次，拉高 `rdata_valid`。
4. 直到 `BYTE_LEN` 满足，置 `done`。

### 9.4 忙等待与超时

- 对 WIP 轮询设定超时计数：
  - `ERASE_TIMEOUT`：用于 4KB 扇区擦除等待。
  - `PROG_TIMEOUT`：用于页写等待。
- 超时则置 `err` 并结束任务。

---

## 10. 地址与计数语义

- 内部地址指针从 `START_ADDR` 开始递增。
- `DEBUG_CNT` 统计已处理字节数（每次写入或读出 4 字节加 4）。
- 当 `DEBUG_CNT == BYTE_LEN` 时，任务完成并置 `done`。
- 若写入超过 `BYTE_LEN`，置 `overflow` 并停止接受 `WDATA`。

---

## 11. 状态与异常处理规则

- `busy`：任务活动期间为 1，结束后清 0。
- `done`：任务结束锁存，W1C 清除。
- `err`：非法流程或超时锁存，W1C 清除。
- `abort`：写 1 后停止当前任务，清 `busy`，不置 `done`。
- 同拍事件冲突：硬件置位优先于 W1C 清除，避免丢失异常。

---

## 12. 复位行为

`presetn=0` 时：

- 清零所有寄存器与状态位。
- `flash_cs_n=1`（空闲），`flash_sclk=0`，`flash_mosi=0`。
- 内部状态机回到 IDLE。

---

## 13. 参数化建议

| 参数名 | 默认值 | 说明 |
| --- | --- | --- |
| `SCLK_DIV` | 2 | `pclk` 分频系数（偶数） |
| `AUTO_ERASE` | 1 | 启动写任务时自动擦除扇区 |
| `ERASE_TIMEOUT` | 32'h00FF_FFFF | 擦除等待超时计数 |
| `PROG_TIMEOUT` | 32'h000F_FFFF | 页写等待超时计数 |

---

## 14. 微架构建议

内部可划分为以下子块：

1. APB 译码与寄存器文件
2. 任务控制 FSM（IDLE/ERASE/WRITE/READ/DONE/ERROR）
3. SPI 时序发生器（SCLK 生成 + MOSI/MISO 移位）
4. WIP 轮询子状态机
5. 数据打包/拆包（32bit <-> byte）

---

## 15. 交付一致性检查清单

1. 寄存器映射与 Phase1 定义完全一致。
2. `pready` 恒 1，`pslverr` 恒 0。
3. `BYTE_LEN` 为 4 字节对齐，否则置 `err`。
4. `WDATA` 写入受 `wdata_ready` 节流。
5. `RDATA` 读取受 `rdata_valid` 节流。
6. `done/err/overflow/underflow` 支持 W1C 清除。
7. SPI 模式固定为 MODE0，地址 24bit。
8. 与 `top.v` 的 SPI 引脚命名一致。
