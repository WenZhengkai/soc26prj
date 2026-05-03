onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/clk
add wave -noupdate /testbench/resetn
add wave -noupdate /testbench/tdi
add wave -noupdate /testbench/tck
add wave -noupdate /testbench/tms
add wave -noupdate /testbench/tdo
add wave -noupdate /testbench/b_pad_gpio_porta
add wave -noupdate /testbench/uart1_rxd
add wave -noupdate /testbench/uart2_rxd
add wave -noupdate /testbench/timer0_extin
add wave -noupdate /testbench/timer1_extin
add wave -noupdate /testbench/i2s_sd
add wave -noupdate /testbench/i2s_sck
add wave -noupdate /testbench/i2s_ws
add wave -noupdate /testbench/flash_cs_n
add wave -noupdate /testbench/flash_sclk
add wave -noupdate /testbench/flash_mosi
add wave -noupdate /testbench/flash_miso
add wave -noupdate /testbench/sample_idx
add wave -noupdate /testbench/bit_idx
add wave -noupdate /testbench/curr_sample
add wave -noupdate /testbench/ws_d1
add wave -noupdate -radix decimal /testbench/sck_edge_cnt
add wave -noupdate /testbench/ws_d2
add wave -noupdate -radix decimal /testbench/error_cnt
add wave -noupdate -radix decimal /testbench/pass_cnt
add wave -noupdate /testbench/spi_shift
add wave -noupdate /testbench/spi_bit_cnt
add wave -noupdate /testbench/spi_cmd
add wave -noupdate /testbench/spi_addr_cnt
add wave -noupdate /testbench/spi_state
add wave -noupdate -divider audio_ctrl
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/pwdata
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/prdata
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/pready
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/pslverr
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/sample_valid
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/sample_data
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/fifo_empty
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/fifo_full
add wave -noupdate -radix decimal /testbench/u_soc/u_audio_ctrl_apb/fifo_level
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/presetn
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/psel
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/penable
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/pwrite
add wave -noupdate /testbench/u_soc/u_audio_ctrl_apb/paddr
add wave -noupdate -divider spi_flash
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/pwrite
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/paddr
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/pwdata
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/prdata
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/pready
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/pslverr
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/flash_cs_n
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/flash_sclk
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/flash_mosi
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/flash_miso
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/pclk
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/presetn
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/psel
add wave -noupdate /testbench/u_soc/u_spi_flash_apb_ctrl/penable
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1002150000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {7642649 ps} {2551859101 ps}
