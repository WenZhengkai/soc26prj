
# 设计文档
## 目的
你是一个数字IC专家, 现在根据要求完成模块设计文档

* 模块名称:i2s_rx_core
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段2：I2S接收核心开发`
* 生成文档到`doc/Phase2_design_i2s_rx_core.md`

## 要求

* 该模板符合业界工程标准, 具有实用性
* 使用markdown格式
* 该文档随后用于设计Verilog模块
* 该文档随后也被用于设计模块对应的testbench, 但是只描述模块本身, 无需验证规划等


### 阶段2：I2S接收核心开发（必须）

#### Phase目标
- 完成 I2S 接收 RTL 核心，能从理想 I2S 时序中稳定提取左声道 24bit PCM 样本。

#### 具体任务清单
- 设计 `i2s_rx_core`
- 确定该模块与I2S接口以及AHB Matrix的连接端口
- 明确对 INMP441 的采样边沿、LRCLK 对齐关系、左声道提取规则
- 增加样本有效脉冲 `sample_valid`
- 支持固定 24bit 输出，屏蔽右声道数据

## INMP441数据手册内容
* INMP441端口
    - SCK: Serial-Data Clock for I²S Interface
    - WS: Serial Data-Word Select for I²S Interface
    - SD: Serial-Data Output for I²S Interface.

* Data Word Length
The output data word length is 24 bits per channel. The INMP441 must always have 64 clock cycles for every stereo data-word (fSCK= 64 × fWS).
* Data-Word Format
The default data format is I²S (two’s complement), MSB-first. In this format, the MSB of each word is delayed by one SCK cycle from the start of each half-frame.


# rtl
##
你是一个数字IC专家, 现在根据文档和要求完成Verilog模块设计

* 阅读设计文档`Phase2_design_i2s_rx_core.md`, 完成rtl设计

* Verilog文件保存在 `./soc-wuxi-arm/audio/rtl/i2s_rx_core.v`

* 参考文件
    - 工程规划文档.md : 整体工程规划
    - soc-wuxi-arm/arm-soc/ : soc框架目录

## 要求
* rtl代码符合工业界规范, 可读性,可维护性强
* 单个always块内只描述一个信号或一组关联性强的信号, 避免单个always块描述所有信号
* 复杂的时序逻辑用`状态机`或`计数器`方式描述

## 设计文档
`Phase2_design_i2s_rx_core.md`



请设计Verilog模块并且保存在指定目录文件