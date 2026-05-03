## 目的
你是一个数字IC, SoC领域专家, 现在设计新增的apb外设文档

* 更改文档`./doc/Phase1_apb_define.md`

## 背景
- 基于现有 `soc-wuxi-arm/` Cortex-M3 SoC 框架，新增录音数据采集与存储能力。
- 阅读当前目录中 @file:工程规划文档.md  了解整体工程设计与规划
- 当前阶段属于Phase1: apb外设方案冻结, 阅读规划文档相应内容

## 要求
* 生成文档保存到`./doc/Phase1_apb_define.md`
* apb新增两个外设: audio_fifo和 spi_flash
* 生成文档中确定外设寄存器/地址映射表, 模块端口定义
* apb相关数据流方案如下:
    - audio_fifo获取到麦克风数据
    - cpu循环检测audio_fifo, 读取有效数据
    - cpu将有效数据保存到spi_flash

* 设计的方案要求可行有效, 仅包含实现基本功能的要素, 没有多余要素

* 该文档后续被用于设计模块的相关参考, 需要确定完备方案


## 要求(SPI FLASH)
* 请重写`spi_flash 外设定义`相关部分
    - spi_flash应当具有完整的读/写功能(不能只有写功能)
* cpu侧的控制逻辑为: i2s采样->cpu访问->cpu转储到spi->完成全部录音->cpu读取spi到内存
    - cpu分批次读取spi_flash内容到内存, 要求符合内存容量限制
    - 程序在keil的调试模式下进行, 每当读取spi_flash一段内容, 进入断点, 手动SAVE内存指定内容到本地
