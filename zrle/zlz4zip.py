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
    
    # Compression Tuning Parameters
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-c", "--compression",
        type=int,
        choices=range(1, 13),
        help="Enable High Compression (LZ4_HC) mode. Level ranges from 1 to 12 (9 is standard)."
    )
    group.add_argument(
        "-a", "--acceleration",
        type=int,
        help="Enable Fast Compression mode with a specified acceleration factor (higher = faster, lower ratio)."
    )

    args = parser.parse_args()

    # Setup compressor configurations
    compress_kwargs = {
        "store_size": False  # CRITICAL: keeps frame data omitted for raw ASM stream parsing
    }
    
    if args.compression is not None:
        compress_kwargs["mode"] = "high_compression"
        compress_kwargs["compression"] = args.compression
    elif args.acceleration is not None:
        compress_kwargs["mode"] = "fast"
        compress_kwargs["acceleration"] = args.acceleration
    else:
        compress_kwargs["mode"] = "default"

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

    # 2. Perform Block Compression
    try:
        compressed_data = lz4.block.compress(input_data, **compress_kwargs)
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
