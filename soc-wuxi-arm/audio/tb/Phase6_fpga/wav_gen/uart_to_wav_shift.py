import argparse
import struct
import wave
from pathlib import Path

SAMPLE_RATE_HZ = 16000
CHANNELS = 1
BITS_PER_SAMPLE = 16
BYTES_PER_SAMPLE_IN = 4

DATA_PATH = Path(__file__).with_name("data.txt")
OUTPUT_PATH = Path(__file__).with_name("output_shift.wav")


def parse_hex_bytes(text):
    cleaned = "".join(text.split())
    if len(cleaned) % 2 != 0:
        raise ValueError("Hex string length must be even.")
    return bytes.fromhex(cleaned)


def le_u32_from_bytes(data, offset):
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)


def apply_shift_24(value, direction):
    value &= 0xFFFFFF
    if direction == "left":
        return (value << 1) & 0xFFFFFF
    if direction == "right":
        return value >> 1
    return value


def sign_extend_24(value):
    value &= 0xFFFFFF
    if value & 0x800000:
        return value - (1 << 24)
    return value


def pcm24_to_pcm16(value):
    value16 = value >> 8
    if value16 > 32767:
        return 32767
    if value16 < -32768:
        return -32768
    return value16


def main():
    parser = argparse.ArgumentParser(description="Convert UART hex stream to WAV with optional 1-bit shift.")
    parser.add_argument("--shift", choices=["none", "left", "right"], default="none")
    parser.add_argument("--out", default=str(OUTPUT_PATH))
    args = parser.parse_args()

    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Missing {DATA_PATH}")

    raw_text = DATA_PATH.read_text(encoding="utf-8", errors="ignore")
    raw_bytes = parse_hex_bytes(raw_text)

    if len(raw_bytes) < BYTES_PER_SAMPLE_IN:
        raise ValueError("Not enough data for a single sample.")

    sample_count = len(raw_bytes) // BYTES_PER_SAMPLE_IN
    trimmed_len = sample_count * BYTES_PER_SAMPLE_IN
    if trimmed_len != len(raw_bytes):
        raw_bytes = raw_bytes[:trimmed_len]

    frames = bytearray()
    for i in range(sample_count):
        offset = i * BYTES_PER_SAMPLE_IN
        word = le_u32_from_bytes(raw_bytes, offset)
        pcm24 = apply_shift_24(word, args.shift)
        pcm24 = sign_extend_24(pcm24)
        pcm16 = pcm24_to_pcm16(pcm24)
        frames += struct.pack("<h", pcm16)

    out_path = Path(args.out)
    with wave.open(str(out_path), "wb") as wav:
        wav.setnchannels(CHANNELS)
        wav.setsampwidth(BITS_PER_SAMPLE // 8)
        wav.setframerate(SAMPLE_RATE_HZ)
        wav.writeframes(frames)

    print(f"Wrote {out_path} with {sample_count} samples")


if __name__ == "__main__":
    main()
