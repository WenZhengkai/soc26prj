# uart
## 
你是一个数字ic专家, 完成soc cpu uart功能


## 背景

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

* soc-wuxi-arm\arm-soc\
    - 使用的soc框架rtl, audio_ctrl_apb模块与soc apb外设总线连接

* 阅读`工程规划文档.md`了解工程整体规划

## 要求
除了main.c不能修改其它库中代码

## 任务
修改以下文件, 增加uart功能
soc-wuxi-arm\audio\tb\Phase6_fpga\keil_test\App\main.c

(当前soc rtl已启用uart1端口, 注意soc rtl中定义了uart1, uart2端口, keil库函数中可能采用了uart0, uart1的计数, 请注意配对正确)

修改原有代码逻辑, 原本从i2s读取sample_data后, 需要传输到spi_flash, 现在移除spi_流程, 读取到sample_data后, 通过uart发送该数据到主机

* 保留sample_data保存在内存中的逻辑用于对照


##
要求程序和soc rtl完全匹配
请不要改动库里原有代码, 只增加文件和代码, 根据 CMSDK APB UART 的寄存器定义，给一版最小可用的 UART 发送驱动接口（初始化 + 发送字节/发送缓冲区）
先在main.c中实现单独的uart测试函数
然后基于main.c实现i2s数据传到uart

## 录音程序与处理程序
接下来请在复制的新的路径中修改程序`soc-wuxi-arm\audio\tb\Phase6_fpga\keil_test_final\App\main.c`

* 请修改main.c, 实现最终工程目标`10-30s`录音
    - 实际录音时间可以用定义的参数设置, 可选择10-30s录音, 也可以实现原有的16个样本数据测试

* 请创建python程序到`soc-wuxi-arm\audio\tb\Phase6_fpga\wav_gen`, 根据串口获取内容转换为wav格式文件, 能够正常播放
    - uart接收完毕后, 用户复制原始内容到wav_gen/data.txt
    - python程序根据原始数据格式和wav转换方法生成wav文件

请先问我3-5个问题明确需求, 再生成设计文档到wav_gen让我审阅, 最后根据文档生成代码文件
