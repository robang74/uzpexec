#!/usr/bin/env python3
import sys
import argparse

class BitWriter:
    def __init__(self):
        self.words = bytearray()
        self.current_word = 0
        self.bit_count = 0

    def write_bit(self, bit):
        # Fill words from MSB (15) down to LSB (0) to match assembly shifts
        if bit:
            self.current_word |= (1 << (15 - self.bit_count))
        self.bit_count += 1
        if self.bit_count == 16:
            self.words.append(self.current_word & 0xFF)
            self.words.append((self.current_word >> 8) & 0xFF)
            self.current_word = 0
            self.bit_count = 0

    def flush(self):
        if self.bit_count > 0:
            self.words.append(self.current_word & 0xFF)
            self.words.append((self.current_word >> 8) & 0xFF)
            self.current_word = 0
            self.bit_count = 0

def write_gamma(bit_writer, val):
    # Standard Elias Gamma encoder (val >= 1)
    binary = bin(val)[2:]
    k = len(binary) - 1
    for _ in range(k):
        bit_writer.write_bit(0)
    for bit in binary:
        bit_writer.write_bit(1 if bit == '1' else 0)

def compress_brieflz_style(data):
    bit_writer = BitWriter()
    data_stream = bytearray()
    
    i = 0
    n = len(data)
    window_size = 65535 # 16-bit window constraint
    
    while i < n:
        match_offset = 0
        match_len = 0
        
        # Scan sliding lookback history window
        start_window = max(0, i - window_size)
        for j in range(start_window, i):
            length = 0
            while i + length < n and data[j + length] == data[i + length]:
                length += 1
                if length == 65535: # Structural bounds ceiling
                    break
            
            if length >= 2 and length > match_len:
                match_len = length
                match_offset = i - j
                
        if match_len >= 2:
            # Token 0: Match Event
            bit_writer.write_bit(0)
            write_gamma(bit_writer, match_len - 1)
            # Commit 16-bit little endian offset
            data_stream.append(match_offset & 0xFF)
            data_stream.append((match_offset >> 8) & 0xFF)
            i += match_len
        else:
            # Token 1: Literal Event
            bit_writer.write_bit(1)
            data_stream.append(data[i])
            i += 1
            
    # Emit End of Stream (EOS) sequence
    bit_writer.write_bit(0)
    write_gamma(bit_writer, 1)
    data_stream.append(0)
    data_stream.append(0)
    
    bit_writer.flush()
    
    tag_stream = bit_writer.words
    tag_size = len(tag_stream)
    
    # Prefix payload layout with tag block stream size descriptor
    header = tag_size.to_bytes(4, byteorder='little')
    return header + tag_stream + data_stream

def main():
    parser = argparse.ArgumentParser(description="BriefLZ-Style Split Stream Encoder.")
    parser.add_argument("input", help="Target input file")
    parser.add_argument("output", help="Target output destination (or '-' for stdout)")
    args = parser.parse_args()

    try:
        with open(args.input, 'rb') as f:
            input_data = f.read()
    except IOError as e:
        print(f"Error reading input: {e}", file=sys.stderr)
        sys.exit(1)

    compressed_data = compress_brieflz_style(input_data)

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
