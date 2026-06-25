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
    print("Errore: la libreria 'lz4' è richiesta.", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Compressore LZ4 raw block per architettura uzpexec.",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("input", help="File di input (usa '-' per stdin)")
    parser.add_argument("output", help="File di output (usa '-' per stdout)")
    
    parser.add_argument(
        "-l", "--level",
        type=int,
        default=6,
        choices=range(1, 13),
        help="Livello di compressione (1-12, default: 6)"
    )

    args = parser.parse_args()

    # Configurazione compressione
    compress_kwargs = {
        "store_size": False,
        "mode": "high_compression",
        "compression": args.level
    }

    # 1. Lettura input
    try:
        if args.input == '-':
            input_data = sys.stdin.buffer.read()
        else:
            with open(args.input, 'rb') as f:
                input_data = f.read()
    except IOError as e:
        print(f"Errore lettura input: {e}", file=sys.stderr)
        sys.exit(1)

    # 2. Compressione
    try:
        compressed_data = lz4.block.compress(input_data, **compress_kwargs)
    except Exception as e:
        print(f"Compressione fallita: {e}", file=sys.stderr)
        sys.exit(1)

    # 3. Scrittura output (corretto per stdout binario)
    try:
        if args.output == '-':
            sys.stdout.buffer.write(compressed_data)
            sys.stdout.buffer.flush()
        else:
            with open(args.output, 'wb') as f:
                f.write(compressed_data)
    except IOError as e:
        print(f"Errore scrittura output: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
