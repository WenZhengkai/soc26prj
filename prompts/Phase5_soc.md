## 目的
你是一个数字IC专家, 现在根据要求完成模块设计文档

* 文档内容:
    - 描述rtl设计任务
    - 描述soc级别testbench开发任务
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段5：录音基本功能闭环联调`, 主要模块已完成, 当前需要将模块接入soc框架并且补充端口
* 生成文档到`doc/Phase5_soc.md`

* 当前阶段3涉及的i2s侧和spi侧已完成, 修改soc框架接入apb外设并且补充端口
    - 例化模块, 连接apb总线, 拓展soc外设端口
    - i2s阶段模块已完成, spi阶段已完成
    - i2s_sck由pclk分频获取, 将i2s_sck:i2s_ws=64:1, 最终i2s_ws约等于16KHz(允许微小误差)
    - pclk先默认设为50MHz, 增加pclk -> i2s_sck, i2s_ws的分频逻辑
* 涉及testbench规划文档, 例化dut为arm-soc的top
    - i2s激励信号由tb产生, 参考`soc-wuxi-arm\audio\tb\Phase3`, 该方案已经相当完善, 可以继承
    - dut的spi外设输出信号作为测试结果对比依据
    - 编写main.c代码, 参考外设定义`Phase1_apb_define.md`, 对i2s侧进行轮询与读取, 将数据保存到spi侧

## 必读资料
* doc\Phase1_apb_define.md
    - 该文档定义了apb外设, 必须严格遵循, 阅读audio_fifo 外设相关定义
* doc\
    - 该目录保存了先前所有模块的设计文档
* soc-wuxi-arm\audio\rtl\
    - 该目录保存了已完成设计与验证的rtl模块
    - i2s_rx_core.v : 已完成验证的i2s接口, fifo写入数据侧需要与该模块连接
    - spi_controller.v : spi控制模块
* soc-wuxi-arm\audio\tb\
    - soc-wuxi-arm\audio\tb\Phase3\testbench.sv : 包含了对i2s外部激励的模拟, 参考其代码.

* soc-wuxi-arm\arm-soc\test.v
    - 最简单的soc tb, 参考该demo版本设计完整的soc tb

* soc-wuxi-arm\arm-soc\
    - 使用的soc框架rtl, audio_ctrl_apb模块与soc apb外设总线连接

## 要求

* 该模板符合业界工程标准, 具有实用性
* 使用markdown格式
* 该文档随后用于设计Verilog模块, agent能够根据该文档正确完成rtl设计.
* 该文档随后也被用于设计模块对应的testbench

* 设计的模块必须与已经完成的rtl模块以及soc框架契合工作

# 实施
## 目的
你是一个数字IC专家, 现在根据要求完成设计和验证任务

* 任务内容:
    - rtl集成任务(基于现有soc框架补充)
    - soc级testbench开发任务(保存到`soc-wuxi-arm\audio\tb\Phase5_soc\testbench.sv`)
    - main.c最小闭环软件任务(保存到`soc-wuxi-arm\audio\tb\Phase5_soc\`)
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段5：录音基本功能闭环联调`, 主要模块已完成, 当前需要将模块接入soc框架并且补充端口
* 详细的开发文档已完成:`doc/Phase5_soc.md`, 请严格遵照该文档完成任务

## 必读资料
* doc\Phase1_apb_define.md
    - 该文档定义了apb外设, 必须严格遵循, 阅读audio_fifo 外设相关定义
* doc\
    - 该目录保存了先前所有模块的设计文档
* soc-wuxi-arm\audio\rtl\
    - 该目录保存了已完成设计与验证的rtl模块
    - i2s_rx_core.v : 已完成验证的i2s接口, fifo写入数据侧需要与该模块连接
    - spi_controller.v : spi控制模块
* soc-wuxi-arm\audio\tb\
    - soc-wuxi-arm\audio\tb\Phase3\testbench.sv : 包含了对i2s外部激励的模拟, 参考其代码.

* soc-wuxi-arm\arm-soc\test.v
    - 最简单的soc tb, 参考该demo版本设计完整的soc tb

* soc-wuxi-arm\arm-soc\
    - 使用的soc框架rtl, audio_ctrl_apb模块与soc apb外设总线连接

## 要求
* rtl代码符合工业界规范, 可读性,可维护性强
* 对dut的输出信号要有自动检测机制, 出现错误时要打印相关信息
* testcase要充分覆盖spec中规定的完整功能与特性


#　Next steps

１．　Build the firmware from main.c:1-62 into cnasic_sleep/prj/keil/output/outfile.bin for the SoC TB to load.

２.　Run the Phase5 SoC simulation with testbench.sv:1-260.

３.　If you want a longer capture, increase SAMPLE_COUNT in both the testbench and firmware.


# 260502soc仿真
仿真发现audio_ctrl模块与spi模块apb使能信号始终为0, 说明cpu未执行到外设访问阶段
* 原因: 没有正确声明程序二进制文件地址

soc执行外设访问, 出现多处spi接收数据与预期结果不一致报错, [FAIL][68690000] SPI data mismatch got=0x08 exp=0x10

# 存储模块技术选型
* 当前SPI FLASH未验证, 而且未实施读逻辑
    - 补充doc\Phase1_apb_define.md spi读取逻辑
    - 重写spi_flash控制模块
    - 补充testbench spi_flash读取测试
    - 补充main.c spi_flash读取流程
* SDRAM方案采用开源ip
    - 补充doc\Phase5_ahb_define.md SDRAM
    - 补充soc 接入AHB SDRAM
    - 补充main.c SDRAM 写入代码
    - 补充soc-wuxi-arm\audio\tb\Phase5_soc


# 260503soc仿真
基于ggy的spi进行 soc系统仿真

* i2s采样信号与tb激励不符
    - tb:`0x00100001`, i2s:`0x00080010`
    - 仿真后观察波形, i2s_sd从sck第3个上升沿才开始输出有效信号, 请调整i2s_sd开始传输信号的时序为第2个sck上升沿

修改后通过测试

# 实施
## 目的
你是一个数字IC专家, 现在根据要求完成设计和验证任务

* 任务内容:
    - spi_flash rtl扩展任务(基于现有模块补充功能)
    - soc级testbench扩展任务(扩展修改`soc-wuxi-arm\audio\tb\Phase5_soc_spi_read\testbench.sv`)
    - main.c最小闭环软件任务, 扩展cpu对spi的读请求任务, 样本数据保存到特定地址内存(扩展`soc-wuxi-arm\audio\tb\Phase5_soc_spi_read\cnasic_sleep\App\main.c`)
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段5：录音基本功能闭环联调`, 主要模块已完成, 当前需要扩展spi模块功能(已经具备write功能), 现在增加read功能
* 详细的开发文档已完成:`doc/Phase5_soc.md`, 请严格遵照该文档完成任务

## 必读资料
* doc\Phase1_apb_define.md
    - 该文档定义了apb外设, 必须严格遵循, 阅读audio_fifo 外设相关定义
    - 请注意, 该文档原本只规定了spi写功能, 目前已经补充了读功能, 相关寄存器/地址等设定发生了变化, 请与旧模块对比并且做出必要修改
* doc\
    - 该目录保存了先前所有模块的设计文档
* soc-wuxi-arm\audio\rtl\
    - 该目录保存了已完成设计与验证的rtl模块
    - i2s_rx_core.v : 已完成验证的i2s接口, fifo写入数据侧需要与该模块连接
    - spi_controller.v : spi控制模块

* soc-wuxi-arm\arm-soc\
    - 使用的soc框架rtl

## 要求
* rtl代码符合工业界规范, 可读性,可维护性强
* 对dut的输出信号要有自动检测机制, 出现错误时要打印相关信息
* testcase要充分覆盖spec中规定的完整功能与特性


## 任务详情
* 请参考外设定义doc\Phase1_apb_define.md扩展spi模块相关部分
    - soc-wuxi-arm\audio\rtl\spi_controller.v
    - soc-wuxi-arm\audio\rtl\spi_module.v
    - spi_flash应当具有完整的读/写功能(不能只有写功能)
* cpu侧的控制逻辑为: i2s采样->cpu访问->cpu转储到spi->完成全部录音->cpu读取spi到内存
    - main.c 扩展cpu对spi的读请求任务, 样本数据保存到特定地址内存
    - cpu分批次读取spi_flash内容到内存, 要求符合内存容量限制

* testbench.sv需要增加对spi读功能的验证
    - cpu从spi发起读请求, 读取样本数据到内存特定区域
    - 读取结束后, tb对比cpu内存中的数据是否与样本数据一致