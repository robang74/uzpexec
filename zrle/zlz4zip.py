#!/usr/bin/env python3
# ==============================================================================
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# ==============================================================================

import sys
import argparse

try:
    import lz4.block
except ImportError:
    print("Error: The 'lz4' library is required.", file=sys.stderr)
    print("Please install it using: pip install lz4", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Universal Raw LZ4 Block Compressor for uzpexec architecture.\n"
                    "Outputs raw byte-aligned token streams compatible with the 512-byte ASM stub.",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        "input",
        help="Input file path (use '-' to read from stdin)"
    )
    parser.add_argument(
        "output",
        help="Output file path (use '-' to write raw stream to stdout)"
    )

    # Parse arguments safely (handles -h / --help automatically)
    args = parser.parse_args()

    # 1. Read input payload
    try:
        if args.input == '-':
            input_data = sys.stdin.buffer.read()
        else:
            with open(args.input, 'rb') as f:
                input_data = f.read()
    except IOError as e:
        print(f"Error reading input: {e}", file=sys.stderr)
        sys.exit(1)

    # 2. Perform Raw LZ4 Block Compression
    try:
        # CRITICAL: store_size=False strips the 4-byte frame header,
        # producing the pure token-stream required by our custom ASM loader loop.
        compressed_data = lz4.block.compress(input_data, store_size=False)
    except Exception as e:
        print(f"Compression failed: {e}", file=sys.stderr)
        sys.exit(1)

    # 3. Write output payload
    try:
        if args.output == '-':
            sys.stdout.buffer.write(compressed_data)
            sys.stdout.buffer.flush()
        else:
            with open(args.output, 'wb') as f:
                f.write(compressed_data)
    except IOError as e:
        print(f"Error writing output: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
