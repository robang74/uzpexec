#!/usr/bin/env python3
# ==============================================================================
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# ==============================================================================

import sys
import argparse

MARKER = 0xAA

def compress_rle(input_path, output_path, min_run):
    try:
        # Read the source binary
        if input_path == '-':
            data = list(sys.stdin.buffer.read())
        else:
            with open(input_path, "rb") as f:
                data = list(f.read())
    except IOError as e:
        print(f"Error reading input: {e}", file=sys.stderr)
        sys.exit(1)

    compressed = bytearray()
    i = 0
    n = len(data)

    while i < n:
        current_byte = data[i]
        run_length = 1
        
        # Count consecutive identical bytes up to the 255 byte limitation
        while i + run_length < n and data[i + run_length] == current_byte and run_length < 255:
            run_length += 1

        # Compress if run meets threshold OR if the literal byte matches our MARKER
        if run_length >= min_run or current_byte == MARKER:
            compressed.append(MARKER)
            compressed.append(run_length)
            compressed.append(current_byte)
            i += run_length
        else:
            compressed.append(current_byte)
            i += 1

    # Determine if we output to stdout or a file
    to_stdout = output_path in ('-', '-c')

    try:
        if to_stdout:
            sys.stdout.buffer.write(compressed)
            sys.stdout.buffer.flush()
            # Status messages must go to stderr so they don't corrupt the stdout stream
            print(f"Compressed {n} bytes down to {len(compressed)} bytes.", file=sys.stderr)
        else:
            with open(output_path, "wb") as f:
                f.write(compressed)
            print(f"Success! Compressed {n} bytes down to {len(compressed)} bytes.")
    except IOError as e:
        print(f"Error writing output: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Custom Marker-Based RLE Compressor")
    parser.add_argument("input", help="Input ELF binary file path (use '-' for stdin)")
    parser.add_argument("output", help="Output file path (use '-' or '-c' for stdout)")
    parser.add_argument("-l", "--level", type=int, default=4, choices=range(3, 16),
                        help="Compression threshold level (minimum consecutive bytes to trigger RLE, default: 4)")

    args = parser.parse_args()
    compress_rle(args.input, args.output, args.level)
