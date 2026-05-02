## 目的
你是一个数字IC专家, 现在根据要求完成模块设计文档

* 文档内容:
    - 描述rtl设计任务
    - 描述soc级别testbench开发任务
* 阅读`工程规划文档.md`了解工程整体规划
* 当前所属阶段`阶段5：录音基本功能闭环联调`, 主要模块已完成, 当前需要将模块接入soc框架并且补充端口
* 生成文档到`doc/Phase3_soc.md`

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