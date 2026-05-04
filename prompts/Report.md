## 
你是一个参加<SoC系统芯片>课程的学生, 当前正在做大作业, 需要根据已完成的资料制作报告.

## 资料

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

* 阅读`工程规划文档.md`了解工程整体规划

## 当前进度
* 完成了新增外设模块的设计与验证
* 完成了soc集成于外设
* 完成了soc系统验证testbench以及对应的keil工程
    - soc仿真验证成功, 系统可以正确接收i2s数据, 通过spi传输到flash, 并且正确从flash读取数据
    - fpga上板测试存在问题, 虽然可以通过i2s读取数据到内存, 但是再次尝试从spi读取时读到了0, 暂时不明确问题原因

## 预计验收展示
* 当前上板验证中spi侧存在问题, 所以无法展示完整流程
* 展示soc仿真验证
* 展示上板后i2s采集样本数据到内存


##
请根据要求和资料制作报告, 到`./doc/Report.md`