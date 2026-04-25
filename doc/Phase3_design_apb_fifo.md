# Phase3 设计文档：audio_fifo + audio_ctrl_apb

## 1. 文档目的与范围

本文档用于阶段3实现输入，定义以下两个模块的可综合、可对接 SoC 的工程级设计规范：

- `audio_fifo`：纯数据 FIFO 子模块（不承载 APB 寄存器语义）
- `audio_ctrl_apb`：APB 从设备控制模块，内部例化 `audio_fifo`

本文档仅描述模块本身设计，不包含验证计划。

设计基线与约束来源：

- `doc/Phase1_apb_define.md`（寄存器语义基线）
- `soc-wuxi-arm/audio/rtl/i2s_rx_core.v`（已验证的 I2S 输出接口）
- `soc-wuxi-arm/arm-soc/`（Cortex-M3 SoC APB 子系统接入框架）

---

## 2. 阶段定位与兼容性约束

当前阶段：**阶段3：APB寄存器 + FIFO + 控制骨架开发**。

兼容性与边界约束（强制）：

1. 寄存器定义以 Phase1 为基线，允许实现细节优化，但保持软件语义兼容。
2. FIFO 接收开关仅使用 `CTRL.bit0 fifo_en`，不新增独立 start/stop 位。
3. `sample_valid` 去重采用**上升沿写入一次**，避免多拍高电平重复入 FIFO。
4. 空 FIFO 读取策略采用“软件等待”：`pready` 恒 1，CPU 先轮询 `STATUS.data_ready` 再读 `DATA`。
5. `underflow` 状态位保留，用于软件误读空 FIFO 的异常观测。
6. `audio_fifo` 保持“纯 FIFO”定位；寄存器与错误/状态控制放在 `audio_ctrl_apb`。

---

## 3. SoC 集成上下文（与现有框架契合）

### 3.1 APB 地址页与扩展端口

按现有 SoC APB 子系统实现：

- APB 从设备按 `PADDR[15:12]` 做 4KB 页解码。
- 扩展端口 `PORT12` 对应地址页 `0xCxxx`。
- 目标外设 `audio_ctrl_apb` 基地址：`0x4000_C000`（扩展端口12）。

### 3.2 与 `apb_subsystem/top` 的接线约束

- `audio_ctrl_apb` 连接 `cmsdk_apb_subsystem` 的 `ext12_*` 信号。
- APB 侧使用：
  - `pclk <- PCLK`
  - `presetn <- PRESETn`
  - `psel <- ext12_psel`
  - `penable <- PENABLE`
  - `pwrite <- PWRITE`
  - `paddr <- PADDR[11:0]`
  - `pwdata <- PWDATA`
  - `prdata -> ext12_prdata`
  - `pready -> ext12_pready`
  - `pslverr -> ext12_pslverr`
- 在 `top` 中启用 APB 扩展参数：`APB_EXT_PORT12_ENABLE=1`。

说明：当前 `top.v` 中扩展端口12/13已预留但未连接，本阶段需完成端口12连接。

---

## 4. 模块A：audio_fifo（纯 FIFO 子模块）

## 4.1 设计目标

`audio_fifo` 仅负责样本缓存与流控，不感知 APB 协议，不包含 W1C/状态寄存器等软件语义。

## 4.2 建议端口定义

```verilog
module audio_fifo #(
    parameter integer DATA_WIDTH = 24,
    parameter integer FIFO_DEPTH = 16
) (
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,

    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  rd_data,

    output wire                   empty,
    output wire                   full,
    output wire [15:0]            level
);
```

> 说明：
> - `level` 固定导出 16bit，满足上层 `audio_ctrl_apb` 端口约束。
> - `FIFO_DEPTH` 建议为 2 的幂；若非 2 的幂，地址回卷逻辑需显式处理。

## 4.3 功能语义

- 写请求：`wr_en=1` 时尝试写入。
  - 若非满：写入成功，`level+1`。
  - 若已满：写入丢弃（上层记录 overflow）。
- 读请求：`rd_en=1` 时尝试读出。
  - 若非空：`rd_data` 更新为被弹出的样本，`level-1`。
  - 若为空：`rd_data` 保持上次值或输出0（二选一并在 RTL 固定），上层记录 underflow。
- 同拍读写：允许；若同拍且均有效，`level` 净变化按 +1/-1 抵消。

## 4.4 复位行为

- `empty=1`，`full=0`，`level=0`。
- 指针与计数器清零。
- `rd_data` 清零（推荐）。

---

## 5. 模块B：audio_ctrl_apb（APB控制 + FIFO例化）

## 5.1 模块端口（冻结）

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

## 5.2 设计职责

`audio_ctrl_apb` 负责：

1. APB 读写译码与寄存器实现。
2. `sample_valid` 去重（上升沿检测）并驱动 FIFO 写入。
3. `fifo_en` 开关控制（CPU 决定是否接收 I2S 数据）。
4. `overflow/underflow` 异常位锁存与 W1C 清除。
5. 对外导出 FIFO 运行状态。

## 5.3 APB 从设备策略

- `pready = 1'b1`（恒定单周期就绪）。
- `pslverr = 1'b0`（本阶段固定无总线错误返回）。
- 有效访问判定：
  - 写：`wr_hit = psel & penable & pwrite`
  - 读：`rd_hit = psel & penable & ~pwrite`

寄存器偏移以 `paddr[11:0]` 为准。

## 5.4 寄存器映射（兼容 Phase1）

基地址：`0x4000_C000`

| 偏移 | 寄存器 | 属性 | 复位值 | 说明 |
| --- | --- | --- | --- | --- |
| 0x00 | CTRL | RW | 0x0000_0000 | FIFO 使能/清空 |
| 0x04 | STATUS | RO/W1C | 0x0000_0001 | FIFO 状态与异常 |
| 0x08 | DATA | RO | 0x0000_0000 | 读口（读即弹出） |
| 0x0C | FIFO_LEVEL | RO | 0x0000_0000 | 当前样本数 |

### 5.4.1 CTRL (0x00)

- bit[0] `fifo_en`：
  - `1`：允许 I2S 样本写入 FIFO（受去重逻辑控制）。
  - `0`：停止接收新样本（不影响 CPU 读出已有数据）。
- bit[1] `fifo_clr`：写1触发 FIFO 清空，自清零。
- bit[31:2]：保留，写0。

### 5.4.2 STATUS (0x04)

- bit[0] `empty`：FIFO 空。
- bit[1] `full`：FIFO 满。
- bit[2] `overflow`：写满时仍请求写入置位，W1C 清除。
- bit[3] `underflow`：空 FIFO 上读 `DATA` 置位，W1C 清除。
- bit[4] `data_ready`：`fifo_level != 0`。
- bit[31:5]：保留。

### 5.4.3 DATA (0x08)

- bit[23:0]：样本数据。
- bit[31:24]：读0。
- 读行为：
  - FIFO 非空：返回弹出样本。
  - FIFO 为空：返回 `0`，并置位 `underflow`。

### 5.4.4 FIFO_LEVEL (0x0C)

- bit[15:0]：当前样本数。
- bit[31:16]：读0。

## 5.5 sample_valid 去重机制（关键约束）

### 5.5.1 背景

来自 `i2s_rx_core` 路径的 `sample_valid` 与 `pclk` 同域，但可能持续多个 `pclk` 周期。若直接电平写 FIFO，会重复入队同一样本。

### 5.5.2 规范实现

在 `audio_ctrl_apb` 内实现 1 拍延迟寄存器：

```verilog
reg sample_valid_d;
wire sample_valid_rise = sample_valid & ~sample_valid_d;
```

FIFO 写使能：

```verilog
fifo_wr_en = fifo_en & sample_valid_rise;
```

行为要求：

- `sample_valid` 每次从 0->1，仅允许写入一次。
- `sample_valid` 保持高电平期间不重复写。
- 下一次写入需等待其回到0后再次上升。

## 5.6 异常与清除优先级

- `overflow` 置位条件：`fifo_wr_en=1` 且 FIFO 已满。
- `underflow` 置位条件：CPU 对 `DATA` 发起读且 FIFO 为空。
- W1C 规则：向 `STATUS` 写 1 清对应位，写0不影响。
- 同拍置位与清除冲突处理建议：**硬件置位优先**（避免丢异常）。

## 5.7 FIFO 清空策略

`CTRL.fifo_clr=1` 时：

1. 同步复位 FIFO 内部指针/计数。
2. `fifo_clr` 自清零。
3. `empty/full/data_ready/level` 在下拍反映清空状态。

建议：`fifo_clr` 对样本写入具有更高优先级（清空拍不接收新样本）。

## 5.8 APB 读写行为细则

### 5.8.1 写事务

- `CTRL`：更新 `fifo_en`，触发 `fifo_clr`。
- `STATUS`：仅处理 W1C 位（bit2/bit3）。
- 其余地址写入：忽略。

### 5.8.2 读事务

- 读 `CTRL/STATUS/FIFO_LEVEL`：返回对应寄存器组合值。
- 读 `DATA`：触发 FIFO 弹出语义。
- 未定义地址：返回 `32'h0000_0000`。

### 5.8.3 读 DATA 的硬件动作顺序

推荐时序定义（与 pready 恒1兼容）：

1. 在 `rd_hit & (paddr==12'h008)` 判断读 `DATA`。
2. 若非空，向 FIFO 发 `rd_en=1`，`prdata` 返回被弹出样本。
3. 若为空，`prdata=0`，`underflow` 置位。

实现可采用“先弹出后返回”或“返回当前读口数据并弹出”两种结构，但必须保证软件可见语义：**每次有效读最多消耗1个样本**。

---

## 6. 微架构建议

## 6.1 audio_ctrl_apb 内部子块

1. APB 访问译码
2. 控制寄存器与 W1C 寄存器
3. `sample_valid` 上升沿检测
4. FIFO 写读仲裁与异常检测
5. 读数据返回多路选择

## 6.2 时序与复位约束

- 全部逻辑工作于 `pclk`。
- 低有效异步复位 `presetn`。
- `sample_data` 在 `sample_valid` 有效窗口内需稳定至少 1 个 `pclk`，以保证边沿捕获正确。

---

## 7. 软件可见行为（驱动语义）

## 7.1 启停流程

1. 写 `CTRL.fifo_en=1` 开始接收。
2. 轮询 `STATUS.data_ready`。
3. `data_ready=1` 时读取 `DATA`。
4. 需要停止采集时写 `CTRL.fifo_en=0`。

## 7.2 异常处理建议

- 若读 `DATA` 前未轮询 `data_ready`，可能触发 `underflow`。
- 软件可定期读取 `STATUS` 并对 `overflow/underflow` 执行 W1C。

---

## 8. 可综合实现约束（RTL落地）

1. 不使用延时语句、不使用不可综合系统任务。
2. 寄存器地址与位定义保持稳定，避免软件接口漂移。
3. `FIFO_DEPTH` 参数变化不影响寄存器地址/位语义。
4. `fifo_level` 输出保持 16 位，深度不足部分高位补0。

---

## 9. 交付一致性检查清单（供实现者自检）

1. `audio_ctrl_apb` 端口与本文档完全一致。
2. `pready` 恒1、`pslverr` 恒0。
3. `CTRL.bit0` 是唯一采集开关。
4. `sample_valid` 仅上升沿入 FIFO 一次。
5. 空 FIFO 读 `DATA` 返回0并置 `underflow`。
6. `overflow/underflow` 支持 W1C。
7. `DATA` 读即弹出，且每次读最多弹1个样本。
8. `audio_fifo` 内不实现 APB/寄存器语义。
9. 与 SoC 扩展端口12地址页 `0x4000_C000` 对齐。

---

## 10. 参考实现骨架（非完整代码，仅接口关系）

```verilog
// audio_ctrl_apb 内部关键关系（示意）
assign pready  = 1'b1;
assign pslverr = 1'b0;

// sample_valid 去重
always @(posedge pclk or negedge presetn) begin
    if (!presetn)
        sample_valid_d <= 1'b0;
    else
        sample_valid_d <= sample_valid;
end

assign fifo_wr_en = fifo_en & sample_valid & ~sample_valid_d;

// 读 DATA 时触发 rd_en（需结合 psel/penable/pwrite/paddr 译码）
assign fifo_rd_en = rd_data_hit & ~fifo_empty;
```

以上骨架仅用于说明关键信号关系，最终 RTL 以本规范行为定义为准。
