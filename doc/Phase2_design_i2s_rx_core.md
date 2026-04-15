# Phase2 设计文档：i2s_rx_core

## 1. 文档目的
定义 `i2s_rx_core` 的模块级设计规格，用于后续 Verilog RTL 编写与模块级 testbench 设计。

## 2. 模块定位与范围
`i2s_rx_core` 负责从 INMP441 的 I2S 串行数据中提取左声道 24bit PCM 样本。

模块职责：
- 接收 I2S 三线输入：`SCK/WS/SD`
- 按 I2S 标准在正确边沿采样 `SD`
- 仅提取左声道 (`WS=0`) 24bit 数据
- 产生单周期样本有效脉冲 `sample_valid`
- 输出固定宽度 `sample_data[23:0]`

模块不负责：
- FIFO 缓冲
- APB/AHB 寄存器访问
- 中断控制
- 跨时钟域同步（本阶段按理想 I2S 时序处理）

## 3. 设计输入依据（INMP441）
- 数据格式：I2S, two’s complement, MSB first
- 位宽：每声道 24bit
- 帧长：每个立体声帧 64 个 SCK 周期（左右各 32bit slot）
- 对齐关系：每个 half-frame 开始后，MSB 相对 `WS` 边界延迟 1 个 SCK 周期

## 4. 顶层端口定义
建议 RTL 端口如下：

| 端口名 | 方向 | 位宽 | 时钟域 | 说明 |
| --- | --- | --- | --- | --- |
| `rst_n` | input | 1 | 异步复位 | 低有效复位 |
| `i2s_sck` | input | 1 | I2S | I2S bit clock |
| `i2s_ws` | input | 1 | I2S | I2S word select (`0`: Left, `1`: Right) |
| `i2s_sd` | input | 1 | I2S | I2S serial data |
| `rx_en` | input | 1 | I2S | 接收使能，`0` 时丢弃输入并清内部状态 |
| `sample_data` | output reg | 24 | I2S | 左声道 24bit PCM 输出 |
| `sample_valid` | output reg | 1 | I2S | 样本有效脉冲（1 个 `i2s_sck` 周期） |

## 5. 与 SoC/AHB Matrix 链路边界
`i2s_rx_core` 不直接连接 AHB Matrix。推荐连接关系：

- I2S 引脚侧：
  - `i2s_sck/i2s_ws/i2s_sd` 来自顶层 `top.v` 的 I2S 外部引脚映射
- SoC 总线侧：
  - `sample_data/sample_valid` 连接到 `audio_fifo` 或 `audio_ctrl_apb` 前端采样口
  - CPU 通过 AHB Matrix -> AHB2APB -> `audio_ctrl_apb` 间接读取样本状态与数据

因此，本模块对总线子系统的接口边界仅为：
- `sample_data[23:0]`
- `sample_valid`

## 6. 时序与采样规则

### 6.1 采样边沿
- 默认在 `i2s_sck` 上升沿采样 `i2s_sd`
- 假设发送端在 `i2s_sck` 下降沿更新 `i2s_sd`（标准 I2S 常用方式）

### 6.2 声道判定
- `i2s_ws=0`：左声道 half-frame
- `i2s_ws=1`：右声道 half-frame（本模块全部丢弃）

### 6.3 左声道提取规则
在检测到 `WS` 从 `1->0` 进入左声道后：
1. 跳过 1 个 `i2s_sck` 周期（对应 I2S 的 MSB 延迟）
2. 连续采集后续 24bit（MSB first）到移位寄存器
3. 第 24bit 采集完成当拍更新 `sample_data`
4. 同拍拉高 `sample_valid=1`
5. 左声道 slot 剩余位（通常 8bit）丢弃，直到 `WS` 变高

### 6.4 右声道处理
- 右声道期间不移位、不更新 `sample_data`
- `sample_valid` 保持 0

## 7. 内部实现建议
建议使用以下寄存器：

| 寄存器名 | 位宽 | 说明 |
| --- | --- | --- |
| `ws_d` | 1 | `i2s_ws` 打拍，用于边沿检测 |
| `shift_reg` | 24 | 左声道数据移位寄存器 |
| `bit_cnt` | 6 | 左声道 slot 内计数（0~31） |
| `left_active` | 1 | 当前处于左声道 half-frame 标记 |

建议控制流程：
- `sample_valid` 每拍默认清零
- `WS` 边沿检测：
  - `1->0`：进入左声道，`bit_cnt` 清零
  - `0->1`：退出左声道，清接收状态
- `left_active` 期间：
  - `bit_cnt==0`：跳过（MSB 延迟位）
  - `bit_cnt=1..24`：执行 `shift_reg <= {shift_reg[22:0], i2s_sd}`
  - `bit_cnt==24` 采样后：`sample_data <= {shift_reg[22:0], i2s_sd}`，`sample_valid<=1`
  - `bit_cnt=25..31`：忽略

## 8. 复位与使能行为
- `rst_n=0`：
  - 清空内部状态与计数器
  - `sample_data` 清零
  - `sample_valid` 清零
- `rx_en=0`：
  - 行为等价于接收逻辑软清空
  - 不输出有效脉冲
- `rx_en` 从 `0->1` 后，模块从下一次合法 `WS` 左声道边界重新同步

## 9. 异常与边界行为定义
为便于 RTL 与 testbench 对齐，统一以下行为：

- 左声道尚未收满 24bit 时若 `WS` 提前翻转：丢弃当前半帧，不输出 `sample_valid`
- `WS` 抖动导致重复边沿：以最近边沿重新同步，未完成样本丢弃
- 非理想帧长（非 32bit slot）：仅按 `WS` 与 `bit_cnt` 规则运行，不做额外纠错

## 10. 输出数据语义
- `sample_data[23:0]`：INMP441 左声道原始 24bit 二补码 PCM
- `sample_valid`：每个有效左声道样本对应 1 个 `i2s_sck` 高脉冲
- 吞吐率：理想情况下每个完整 I2S 帧输出 1 个样本（16kHz 对应 16k sample/s）

## 11. 参数化建议（可选）
建议 RTL 支持以下参数，默认值满足当前项目：

| 参数名 | 默认值 | 说明 |
| --- | --- | --- |
| `SAMPLE_WIDTH` | 24 | 输出样本位宽 |
| `SLOT_WIDTH` | 32 | 单声道 slot 宽度 |
| `WS_POL_LEFT` | 1'b0 | 左声道 WS 电平定义 |

当前阶段固定配置：`SAMPLE_WIDTH=24`，`SLOT_WIDTH=32`。

## 12. 可直接用于 testbench 的检查点
以下是模块行为检查点（仅针对模块本身）：

- 在合法 I2S 左声道输入下，`sample_data` 与期望 24bit 序列一致
- `sample_valid` 仅在每个左声道样本完成时拉高 1 拍
- 右声道数据变化不影响输出结果
- 复位后可在后续帧重新锁定并正确输出
- 左右声道边界处无 bit slip（不多一位、不错一位）

## 13. 版本信息
- 文档版本：v1.0
- 对应阶段：阶段2（I2S接收核心开发）
- 目标模块：`i2s_rx_core`
