# 设计文档
## 目的
你是一个数字IC专家, 现在根据要求完成模块设计文档

* 模块名称:
    -  `audio_fifo`
    -  `audio_ctrl_apb` (内部例化`audio_fifo`)
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段3：APB寄存器 + FIFO + 控制骨架开发`
* 生成文档到`doc/Phase3_design_apb_fifo.md`

## 必读资料
* doc\Phase1_apb_define.md
    - 该文档定义了apb外设, 必须严格遵循, 阅读audio_fifo 外设相关定义
* soc-wuxi-arm\audio\rtl\i2s_rx_core.v
    - 已完成验证的i2s接口, fifo写入数据侧需要与该模块连接
* soc-wuxi-arm\arm-soc\
    - 使用的soc框架rtl, audio_ctrl_apb模块与soc apb外设总线连接

## 要求

* 该模板符合业界工程标准, 具有实用性
* 使用markdown格式
* 该文档随后用于设计Verilog模块, agent能够根据该文档正确完成rtl设计.
* 该文档随后也被用于设计模块对应的testbench, 但是只描述模块本身, 无需验证规划等

* 设计的模块必须与已经完成的rtl模块以及soc框架契合工作

* `audio_ctrl_apb`模块端口定义如下:
``` Verilog
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

* `sample_valid`控制fifo写入, 但是由于是`pclk`分频时钟相关信号, sample_valid会持续多个`pclk`周期, 此处需要处理, 避免重复写入fifo

* cpu侧决定该外设工作开关, cpu控制fifo开始和停止接收i2s侧的数据

## 需求边界
寄存器定义以Phase1为基线，可小改但必须保持软件语义兼容。
FIFO接收开关仅使用 CTRL.bit0 fifo_en，不新增独立 start/stop 位。
sample_valid 去重采用上升沿写入一次，避免多拍高电平重复入FIFO。
空FIFO读取策略采用“软件等待”：pready 恒1，CPU先轮询 STATUS.data_ready 再读 DATA。
underflow 状态位保留，用于软件误读空FIFO时的异常观测。
audio_fifo 作为纯FIFO子模块；寄存器与错误/状态控制逻辑放在 audio_ctrl_apb。



# rtl
##
你是一个数字IC专家, 现在根据文档和要求完成Verilog模块设计

* 阅读设计文档`Phase3_design_apb_fifo.md`, 完成rtl设计

* Verilog文件保存在 `./soc-wuxi-arm/audio/rtl/`

* 参考文件
    - 工程规划文档.md : 整体工程规划
    - soc-wuxi-arm/arm-soc/ : soc框架目录

## 要求
* rtl代码符合工业界规范, 可读性,可维护性强
* 单个always块内只描述一个信号或一组关联性强的信号, 避免单个always块描述所有信号
* 复杂的时序逻辑用`状态机`或`计数器`方式描述

## 设计文档
`Phase3_design_apb_fifo.md`内容如下



请设计Verilog模块并且保存在指定目录文件

# tb
##
你是一个数字IC验证专家, 现在根据文档和要求完成testbench.sv的设计
* 参考文件
    - 工程规划文档.md : 整体工程规划
    - soc-wuxi-arm/arm-soc/ : soc框架目录
* 当前所属阶段`阶段3：APB寄存器 + FIFO + 控制骨架开发`
* 待验证模块: audio_ctrl_apb
* dut文件路径:soc-wuxi-arm\audio\rtl\audio_ctrl_apb.v
* dut spec路径:doc\Phase3_design_apb_fifo.md
* testbench文件保存在 `soc-wuxi-arm\audio\tb\Phase3\`

## 要求
* 对dut的输出信号要有自动检测机制, 出现错误时要打印相关信息
* testcase要充分覆盖spec中规定的完整功能与特性
* dut为`audio_ctrl_apb`, tb内还需例化已验证模块`i2s_rx_core`, 将其与dut连接
* tb内需要模拟来自`apb总线`的激励以及`i2s端口`的激励
* 总体构成为: apb总线-> dut <- i2s_rx_core <- i2s端口
* i2s端口激励请参考上阶段已完成tb: soc-wuxi-arm\audio\tb\Phase2\testbench.sv
* i2s端口激励请注意只随机生成左声道信号, 与实际上板条件相同

* 时钟频率问题
    - i2s_sck由pclk分频获取, 将i2s_sck:i2s_ws=64:1, 最终i2s_ws约等于16KHz(允许微小误差)
    - pclk先默认设为50MHz, 增加pclk -> i2s_sck的分频逻辑

# debug

## 问题1
* i2s_ws 第一个周期, 接收模块没有及时从idle转为左声道模式

* i2s_ws 首次出现下降沿: 320ns, 此前i2s_sck保持为0, 直到610ns才出现上升沿
* i2s_ws 首次下降沿后, tb就开始传输麦克风数据, 但是i2s_rx_core时钟还未翻转, 无法捕获ws下降沿, 进而无法转换到左声道状态
* 应当延后ws首次下降沿时间, 与sck上升沿时间同步

## 问题2
* 接收模块的左声道状态持续时间与i2s_ws周期不匹配

* i2s_rx_core最初处于短暂的右声道状态, 其计数器经历`0, 1, 2`后i2s_ws下降沿提前到来, 状态强制转换为`左声道状态`, 但是计数器没有清零, 继续计数`3, 4, 5 ...`
* 下一个i2s_ws上升沿到来之前, 计数器记到`cnt=31`, 提前进入`右声道状态`, 此后i2s_rx_core状态与ws信号不对齐

* 状态机的状态转移相关代码片段如下:
``` Verilog
        LEFT: begin
            // Fix 1: SLOT_WIDTH-1 而非 SLOT_WIDTH
            if (cnt == SLOT_WIDTH - 1)
                next_state = RIGT;
            else if (enter_right)       // 容错：WS 边沿提前
                next_state = RIGT;
            else
                next_state = LEFT;
        end
```
* 优先使用`cnt`控制状态转移, 又补充了ws边沿作为容错控制

* 方案1: cnt本身不适合作为状态转移的控制信号, 应当单纯依赖ws边沿进行状态转移, 同时要增加在`状态转移`后`cnt`立即复位机制
    - ws对于状态转移和cnt复位的影响优先级应当是最高的
* 方案2: 保留cnt控制状态转移的机制, 增加cnt复位机制
    - 如果ws因为某些原因延后到来, 状态机将会与ws不对齐

## 问题3
* tb发出错误信息i2s_rx_core sample_valid count mismatch, seen=0
* 每当i2s_ws下降沿附近, 发出该报错

* 设计规定i2s_ws高电平时为`右声道状态`, tb无需发送右声道信号, i2s_rx_core也无需在该状态接收信息, 因此不需要在i2s_ws下降沿附近发出sample_valid

* tb可能存在错误, 在右声道状态预期i2s_rx_core会产生valid信号