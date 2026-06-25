#!/usr/bin/env python3
# ==============================================================================
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# ==============================================================================
import sys

MARKER = 0xAA

def compress_rle(input_path, output_path):
    try:
        with open(input_path, "rb") as f:
            data = list(f.read())
    except IOError as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        sys.exit(1)

    compressed = bytearray()
    i = 0
    n = len(data)

    while i < n:
        current_byte = data[i]
        run_length = 1
        
        # Count consecutive identical bytes (up to max 255 bytes for a single byte length)
        while i + run_length < n and data[i + run_length] == current_byte and run_length < 255:
            run_length += 1

        # Criteria: compress if run is >= 4 bytes OR if the literal byte itself happens to be our Marker
        if run_length >= 4 or current_byte == MARKER:
            compressed.append(MARKER)
            compressed.append(run_length)
            compressed.append(current_byte)
            i += run_length
        else:
            # Write literal bytes individually
            compressed.append(current_byte)
            i += 1

    try:
        with open(output_path, "wb") as f:
            f.write(compressed)
        print(f"Success! Compressed {n} bytes down to {len(compressed)} bytes.")
    except IOError as e:
        print(f"Error writing output file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 rle_compress.py <input_elf> <output_rle_bin>")
        sys.exit(1)
    compress_rle(sys.argv[1], sys.argv[2])
