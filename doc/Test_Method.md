## SoC上板测试

### 管脚连接
i2s_sck - PIN_AA15
i2s_sd  - PIN_W13
i2s_ws  - PIN_AB13
i2s_lr  - GND
i2s_gnd - GND
i2s_vdd - VDD

flash_cs_n  - PIN_Y5
flash_miso  - PIN_Y4
flash_mosi  - PIN_Y3
flash_sclk  - PIN_AA2
flash_gnd   - GND
flash_vdd   - VDD

uart1_rxd   -       - u_tx
uart1_txd   -       - u_rx

### 上板演示步骤
* 连接
* 打开Quartus工程
* 下载二进制文件到fpga

## SoC完整功能仿真测试
* 进入`soc-wuxi-arm\audio\tb\Phase5_soc_spi_read`
* 使用Keil打开cnasic_sleep
* 编译代码生成.bin文件
* 使用modelsim打开仿真工程文件
    - 该tb中模拟了i2s_MIC激励信号, 产生16个递增样本信号(24bit); 模拟了spi_flash设备用于数据收发
    - tb中例化了SoC顶层作为dut, dut采样i2s信号, 并通过spi存储到flash
    - tb会逐个对比i2s原始数据与soc向spi写操作时的输出数据
    - soc向spi发出读请求,转存数据到内存, tb对比原始数据与内存中的数据
* 运行仿真, 查看端口验证结果


运行结果如下
```
run -all
# [TB] RAM loaded
# [PASS][63390000] WS half-frame SCK count=31
# [PASS][66030000] SPI data match    got=0x00 exp=0x00
# [PASS][67370000] SPI data match    got=0x00 exp=0x00
# [PASS][68710000] SPI data match    got=0x10 exp=0x10
# [PASS][70050000] SPI data match    got=0x00 exp=0x00
# [PASS][94630000] WS half-frame SCK count=31
# [PASS][125890000] WS half-frame SCK count=31
# [PASS][128410000] SPI data match    got=0x01 exp=0x01
# [PASS][129750000] SPI data match    got=0x00 exp=0x00
# [PASS][131090000] SPI data match    got=0x10 exp=0x10
# [PASS][132430000] SPI data match    got=0x00 exp=0x00
# [PASS][157130000] WS half-frame SCK count=31
# [PASS][191210000] SPI data match    got=0x02 exp=0x02
# [PASS][192550000] SPI data match    got=0x00 exp=0x00
# [PASS][193890000] SPI data match    got=0x10 exp=0x10
# [PASS][195230000] SPI data match    got=0x00 exp=0x00
# [PASS][253590000] SPI data match    got=0x03 exp=0x03
# [PASS][254930000] SPI data match    got=0x00 exp=0x00
# [PASS][256270000] SPI data match    got=0x10 exp=0x10
# [PASS][257610000] SPI data match    got=0x00 exp=0x00
# [PASS][315970000] SPI data match    got=0x04 exp=0x04
# [PASS][317310000] SPI data match    got=0x00 exp=0x00
# [PASS][318650000] SPI data match    got=0x10 exp=0x10
# [PASS][319990000] SPI data match    got=0x00 exp=0x00
# [PASS][378350000] SPI data match    got=0x05 exp=0x05
# [PASS][379690000] SPI data match    got=0x00 exp=0x00
# [PASS][381030000] SPI data match    got=0x10 exp=0x10
# [PASS][382370000] SPI data match    got=0x00 exp=0x00
# [PASS][441150000] SPI data match    got=0x06 exp=0x06
# [PASS][442490000] SPI data match    got=0x00 exp=0x00
# [PASS][443830000] SPI data match    got=0x10 exp=0x10
# [PASS][445170000] SPI data match    got=0x00 exp=0x00
# [PASS][503530000] SPI data match    got=0x07 exp=0x07
# [PASS][504870000] SPI data match    got=0x00 exp=0x00
# [PASS][506210000] SPI data match    got=0x10 exp=0x10
# [PASS][507550000] SPI data match    got=0x00 exp=0x00
# [PASS][565910000] SPI data match    got=0x08 exp=0x08
# [PASS][567250000] SPI data match    got=0x00 exp=0x00
# [PASS][568590000] SPI data match    got=0x10 exp=0x10
# [PASS][569930000] SPI data match    got=0x00 exp=0x00
# [PASS][628710000] SPI data match    got=0x09 exp=0x09
# [PASS][630050000] SPI data match    got=0x00 exp=0x00
# [PASS][631390000] SPI data match    got=0x10 exp=0x10
# [PASS][632730000] SPI data match    got=0x00 exp=0x00
# [PASS][691090000] SPI data match    got=0x0a exp=0x0a
# [PASS][692430000] SPI data match    got=0x00 exp=0x00
# [PASS][693770000] SPI data match    got=0x10 exp=0x10
# [PASS][695110000] SPI data match    got=0x00 exp=0x00
# [PASS][753470000] SPI data match    got=0x0b exp=0x0b
# [PASS][754810000] SPI data match    got=0x00 exp=0x00
# [PASS][756150000] SPI data match    got=0x10 exp=0x10
# [PASS][757490000] SPI data match    got=0x00 exp=0x00
# [PASS][815850000] SPI data match    got=0x0c exp=0x0c
# [PASS][817190000] SPI data match    got=0x00 exp=0x00
# [PASS][818530000] SPI data match    got=0x10 exp=0x10
# [PASS][819870000] SPI data match    got=0x00 exp=0x00
# [PASS][878650000] SPI data match    got=0x0d exp=0x0d
# [PASS][879990000] SPI data match    got=0x00 exp=0x00
# [PASS][881330000] SPI data match    got=0x10 exp=0x10
# [PASS][882670000] SPI data match    got=0x00 exp=0x00
# [PASS][941030000] SPI data match    got=0x0e exp=0x0e
# [PASS][942370000] SPI data match    got=0x00 exp=0x00
# [PASS][943710000] SPI data match    got=0x10 exp=0x10
# [PASS][945050000] SPI data match    got=0x00 exp=0x00
# [PASS][1003410000] SPI data match    got=0x0f exp=0x0f
# [PASS][1004750000] SPI data match    got=0x00 exp=0x00
# [PASS][1006090000] SPI data match    got=0x10 exp=0x10
# [PASS][1007430000] SPI data match    got=0x00 exp=0x00
# [PASS][1112870000] CPU read done flag
# [PASS][1112870000] SRAM readback match    idx=0 val=0x00100000
# [PASS][1112870000] SRAM readback match    idx=1 val=0x00100001
# [PASS][1112870000] SRAM readback match    idx=2 val=0x00100002
# [PASS][1112870000] SRAM readback match    idx=3 val=0x00100003
# [PASS][1112870000] SRAM readback match    idx=4 val=0x00100004
# [PASS][1112870000] SRAM readback match    idx=5 val=0x00100005
# [PASS][1112870000] SRAM readback match    idx=6 val=0x00100006
# [PASS][1112870000] SRAM readback match    idx=7 val=0x00100007
# [PASS][1112870000] SRAM readback match    idx=8 val=0x00100008
# [PASS][1112870000] SRAM readback match    idx=9 val=0x00100009
# [PASS][1112870000] SRAM readback match    idx=10 val=0x0010000a
# [PASS][1112870000] SRAM readback match    idx=11 val=0x0010000b
# [PASS][1112870000] SRAM readback match    idx=12 val=0x0010000c
# [PASS][1112870000] SRAM readback match    idx=13 val=0x0010000d
# [PASS][1112870000] SRAM readback match    idx=14 val=0x0010000e
# [PASS][1112870000] SRAM readback match    idx=15 val=0x0010000f
# [TB] PASS
# ** Note: $finish    : E:/soc26prj/soc-wuxi-arm/audio/tb/Phase5_soc_spi_read/testbench.sv(389)
#    Time: 5112870 ns  Iteration: 1  Instance: /testbench
```


