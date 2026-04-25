onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_audio_ctrl_apb_phase3/pclk
add wave -noupdate /tb_audio_ctrl_apb_phase3/rst_n
add wave -noupdate /tb_audio_ctrl_apb_phase3/i2s_sck
add wave -noupdate /tb_audio_ctrl_apb_phase3/i2s_div_acc
add wave -noupdate /tb_audio_ctrl_apb_phase3/psel
add wave -noupdate /tb_audio_ctrl_apb_phase3/penable
add wave -noupdate /tb_audio_ctrl_apb_phase3/pwrite
add wave -noupdate /tb_audio_ctrl_apb_phase3/paddr
add wave -noupdate /tb_audio_ctrl_apb_phase3/pwdata
add wave -noupdate /tb_audio_ctrl_apb_phase3/prdata
add wave -noupdate /tb_audio_ctrl_apb_phase3/pready
add wave -noupdate /tb_audio_ctrl_apb_phase3/pslverr
add wave -noupdate /tb_audio_ctrl_apb_phase3/i2s_ws
add wave -noupdate /tb_audio_ctrl_apb_phase3/i2s_sd
add wave -noupdate /tb_audio_ctrl_apb_phase3/i2s_sample_data
add wave -noupdate /tb_audio_ctrl_apb_phase3/i2s_sample_valid
add wave -noupdate /tb_audio_ctrl_apb_phase3/fifo_empty
add wave -noupdate /tb_audio_ctrl_apb_phase3/fifo_full
add wave -noupdate /tb_audio_ctrl_apb_phase3/fifo_level
add wave -noupdate -radix decimal /tb_audio_ctrl_apb_phase3/error_cnt
add wave -noupdate -radix decimal /tb_audio_ctrl_apb_phase3/pass_cnt
add wave -noupdate -radix unsigned /tb_audio_ctrl_apb_phase3/u_i2s_rx_core/state
add wave -noupdate -radix decimal /tb_audio_ctrl_apb_phase3/u_i2s_rx_core/cnt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {628030000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 122
configure wave -valuecolwidth 40
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
WaveRestoreZoom {627941343 ps} {628118657 ps}
