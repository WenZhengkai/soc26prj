# Phase5 SoC集成与联调设计文档（阶段5使用）

## 1. 目的与范围

本文件用于阶段5的SoC闭环联调，明确RTL集成任务与SoC级testbench开发任务，确保已完成的I2S与SPI模块能在Cortex-M3 SoC框架中闭环运行。

覆盖范围：
- SoC顶层与APB子系统的接入改造
- I2S时钟分频与WS生成逻辑
- I2S样本进入APB音频FIFO的跨域处理
- SoC级testbench规划与检查点
- main.c最小闭环软件流程

不覆盖范围：
- I2S RX与SPI控制器内部细节（已完成模块）
- Flash擦写策略优化与DMA扩展

## 2. 设计输入与冻结约束

- APB寄存器定义与地址映射：doc/Phase1_apb_define.md
- FIFO与APB控制：doc/Phase3_design_apb_fifo.md
- I2S RX核心：doc/Phase2_design_i2s_rx_core.md
- SoC框架：soc-wuxi-arm/arm-soc/
- 参考I2S激励：soc-wuxi-arm/audio/tb/Phase3/testbench.sv

冻结约束：
- APB外设地址页不变：audio_fifo=0x4000_C000，spi_flash=0x4000_D000
- 采样格式为单声道左声道24bit PCM
- i2s_sck:i2s_ws=64:1，i2s_ws约16KHz
- pclk默认50MHz

## 3. RTL集成任务

### 3.1 顶层端口扩展

在SoC顶层增加以下外设引脚：
- I2S输入：i2s_sd（来自麦克风）
- I2S输出：i2s_sck、i2s_ws（由SoC生成）
- SPI Flash：flash_cs_n、flash_sclk、flash_mosi、flash_miso

端口命名需与SoC约定一致，便于约束与testbench连接。

### 3.2 APB扩展端口接入

在APB子系统启用扩展端口12与13，用于连接audio_fifo与spi_flash外设：
- ext12 -> audio_ctrl_apb
- ext13 -> spi_flash_apb_ctrl

需完成：
- 参数使能：APB_EXT_PORT12_ENABLE=1，APB_EXT_PORT13_ENABLE=1
- 总线信号接线：psel/prdata/pready/pslverr

### 3.3 模块例化与连接关系

在顶层例化并连线：
- i2s_rx_core：i2s_sck/i2s_ws/i2s_sd -> sample_valid/sample_data
- audio_ctrl_apb：APB端口接ext12，sample_valid/sample_data输入
- spi_flash_apb_ctrl：APB端口接ext13，SPI引脚输出

数据流：
- i2s_rx_core -> audio_ctrl_apb -> CPU读取 -> spi_flash_apb_ctrl

### 3.4 i2s_sck与i2s_ws生成逻辑

目标频率：
- pclk = 50MHz
- i2s_ws = 16kHz
- i2s_sck = i2s_ws * 64 = 1.024MHz

分频方案建议采用小数分频累加器（与Phase3 testbench一致），保证长时间平均频率准确：

- 每个pclk周期累加acc += 2 * i2s_sck
- 若acc >= pclk，则acc -= pclk并翻转i2s_sck
- i2s_ws由i2s_sck计数生成：
  - 在i2s_sck上升沿计数slot_cnt
  - slot_cnt达到31时翻转i2s_ws（32个sck为半帧）

说明：i2s_ws低电平为左声道。

### 3.5 sample_valid跨域处理

i2s_rx_core工作在i2s_sck域，audio_ctrl_apb在pclk域。两者时钟分频关系


audio_ctrl_apb接收sample_valid与sample_data。其内部已经做过处理, 顶层无需处理.

## 4. SoC级Testbench开发任务

### 4.1 基础框架

使用soc-wuxi-arm/arm-soc/test.v为骨架：
- 例化DUT为arm-soc顶层
- 维持ROM加载与复位流程
- 增加I2S与SPI外设信号连接

### 4.2 I2S激励生成

复用soc-wuxi-arm/audio/tb/Phase3/testbench.sv中的I2S激励方案：
- i2s_sck, i2s_ws由soc产生(此处与Phase3不同, 两个信号无需再由tb产生)
- i2s_sd按I2S时序驱动
- 仅驱动左声道样本，右声道填0
- 采样数据序列可使用递增或固定模式，便于SPI结果比对

### 4.3 SPI结果比对

DUT的SPI输出信号作为测试结果依据：
- 监视flash_cs_n/flash_sclk/flash_mosi
- 当CS有效时，根据SCLK采样MOSI，重组字节流
- 解析写入序列，期望与I2S输入样本一致（每样本按32bit对齐，低24bit有效）

可以采用简单SPI Flash行为模型，也可直接在tb中实现采样解码与scoreboard。

### 4.4 关键检查点

- i2s_sck与i2s_ws频率关系稳定，i2s_ws约16kHz
- audio_fifo状态位与FIFO_LEVEL变化合理
- CPU完成轮询读取与写入流程
- SPI写入数据序列与I2S输入一致

## 5. main.c最小闭环软件任务

参考doc/Phase1_apb_define.md，完成以下流程：
demo模板: `soc-wuxi-arm\cnasic_sleep\App\main.c`

1) 配置SPI写入任务
- START_ADDR与BYTE_LEN
- CTRL.start=1

2) 轮询搬运
- 轮询audio_fifo.STATUS.data_ready
- 读取audio_fifo.DATA得到24bit样本
- 轮询spi_flash.STATUS.wdata_ready
- 写spi_flash.WDATA（低24bit有效，高8bit填0）

3) 完成处理
- 轮询spi_flash.STATUS.done
- W1C清done状态

说明：不依赖中断，主线采用轮询模式。

## 6. 验收标准

- SoC级仿真通过，CPU可完成I2S数据到SPI写入的闭环
- I2S输入样本与SPI写入序列一致
- i2s_sck:i2s_ws=64:1，i2s_ws约16kHz，允许微小误差
- APB寄存器访问与Phase1定义完全一致
