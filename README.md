# SoC Audio Capture over UART

This project extends a Cortex-M3 SoC platform with a UART-based audio capture pipeline. It adds a simple recording flow that reads I2S samples through an APB audio FIFO and streams them over UART for offline conversion to WAV.

## Highlights
- I2S RX core integrated with APB audio FIFO
- UART streaming path for audio samples (32-bit little-endian words, low 24-bit valid)
- 10-30s configurable recording in firmware
- Offline WAV generation from captured UART data

## Repository Layout
- doc/ - Design notes, test methods, and phase reports
- prompts/ - Project phase prompts and task tracking notes
- soc-wuxi-arm/ - SoC RTL, testbenches, and firmware projects
- Quartus/ - FPGA project files
- Quartus-back/ - Backup of Quartus project
- QuartusExample/ - Example Quartus build artifacts
- test_uvm/ - UVM testbench assets

## Recording Flow
1. Build and run firmware:
   - Firmware target: soc-wuxi-arm/audio/tb/Phase6_fpga/keil_test_final/App/main.c
   - Configure `RECORD_SECONDS` for 10-30 seconds
   - UART settings: 921600, 8N1

2. Capture UART data:
   - Save raw bytes and paste hex to:
     - soc-wuxi-arm/audio/tb/Phase6_fpga/wav_gen/data.txt
   - The file should contain a continuous hex string (whitespace is ignored)

3. Convert to WAV:
   - Run the converter:
     - python uart_to_wav.py
   - Output:
     - soc-wuxi-arm/audio/tb/Phase6_fpga/wav_gen/output.wav

4. If the audio sounds distorted, try 1-bit alignment compensation:
   - python uart_to_wav_shift.py --shift left
   - python uart_to_wav_shift.py --shift right

## Data Format
- Each sample is sent as 4 bytes (little-endian)
- Low 24 bits are valid audio data
- High 8 bits are invalid and ignored during WAV generation

## Requirements
- Python 3.8+ for WAV conversion scripts
- Serial terminal that supports 921600 baud

## Status
- UART streaming and WAV conversion are functional
- Audio alignment may require a 1-bit shift depending on I2S timing

## License
Add a license file if you plan to open-source the repository.
