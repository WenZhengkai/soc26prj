# 设计文档
## 目的
你是一个数字IC专家, 现在根据要求完成模块设计文档

* 模块名称:
    -  `spi_flash_apb_ctrl`
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段4：存储通路最小闭环开发`
* 生成文档到`doc/Phase4_design_apb_spi.md`

## 必读资料
* doc\Phase1_apb_define.md
    - 该文档定义了apb外设, 必须严格遵循, 阅读audio_fifo 外设相关定义
* soc-wuxi-arm\audio\rtl\
    - 已完成验证的rtl
* soc-wuxi-arm\arm-soc\
    - 使用的soc框架rtl, audio_ctrl_apb模块与soc apb外设总线连接

## 要求

* 该模板符合业界工程标准, 具有实用性
* 使用markdown格式
* 该文档随后用于设计Verilog模块, agent能够根据该文档正确完成rtl设计.
* 该文档随后也被用于设计模块对应的testbench, 但是只描述模块本身, 无需验证规划等

* 设计的模块必须与已经完成的rtl模块以及soc框架契合工作



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


# rtl
##
你是一个数字IC专家, 现在根据文档和要求完成Verilog模块设计

* 阅读设计文档`doc\Phase4_design_apb_spi.md`, 完成rtl设计

* Verilog文件保存在 `./soc-wuxi-arm/audio/rtl/`

* 参考文件
    - 工程规划文档.md : 整体工程规划
    - `doc\Phase1_apb_define.md` : 外设定义文档
    - soc-wuxi-arm/arm-soc/ : soc框架目录

## 要求
* rtl代码符合工业界规范, 可读性,可维护性强
* 单个always块内只描述一个信号或一组关联性强的信号, 避免单个always块描述所有信号
* 复杂的时序逻辑用`状态机`或`计数器`方式描述

## 设计文档
`doc\Phase4_design_apb_spi.md`, 严格遵循文档进行设计



请设计Verilog模块并且保存在指定目录文件