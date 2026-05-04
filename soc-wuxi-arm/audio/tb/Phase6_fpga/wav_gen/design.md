# Phase6 FPGA UART Audio Capture - Design

## Goals
- Capture 10-30s of I2S audio and stream over UART.
- Data is raw samples (32-bit little-endian words) with top 8 bits invalid.
- Generate a WAV file (16-bit PCM for compatibility) from UART data.

## Constraints
- Do not modify existing library code; only update main.c and add new files.
- main.c must not store samples in a memory buffer.
- UART uses CMSDK APB UART (UART1 base 0x40005000).

## UART Data Format
- Each sample is sent as 4 bytes, little-endian.
- Only low 24 bits are valid; high 8 bits are invalid and ignored.
- No extra framing or test patterns in final build.

## main.c Plan
- Provide macros to select record duration (seconds) and test mode (16 samples).
- Calculate sample count: duration_sec * 16000.
- Loop until sample count is reached:
  - Wait for FIFO ready.
  - Read AUD_DATA (32-bit).
  - Send 4 bytes over UART (little-endian).
- Write DONE flag when complete.

## WAV Generator (Python)
- Input: wav_gen/data.txt containing continuous hex string (whitespace ignored).
- Parse hex into bytes, group into 4-byte words (little-endian).
- For each word:
  - Take low 24 bits as signed PCM (two's complement).
  - Convert to 16-bit PCM by right shift 8 (with sign).
- Write WAV with:
  - Sample rate: 16000 Hz
  - Channels: 1 (left)
  - Bits per sample: 16

## Outputs
- wav_gen/output.wav
- Console prints sample count and any input length errors.
