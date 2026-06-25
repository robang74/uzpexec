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
    window_size = 65535  # 16-bit window constraint
    
    # Hash table mapping 2-byte sequences to a list of recent positions
    pos_hash = {}
    # Capping candidates speeds up compression to near-instantaneous execution
    MAX_CANDIDATES = 16 
    
    while i < n:
        match_offset = 0
        match_len = 0
        
        # We need at least 2 bytes left to attempt a match lookup
        if i + 1 < n:
            two_bytes = (data[i] << 8) | data[i+1]
            if two_bytes in pos_hash:
                candidates = pos_hash[two_bytes]
                # Scan occurrences from newest (most recent) to oldest
                for j in reversed(candidates):
                    if i - j > window_size:
                        break  # Stop checking: older matches are out of window range
                    
                    length = 2
                    while i + length < n and data[j + length] == data[i + length]:
                        length += 1
                        if length == 65535:  # Structural bounds ceiling
                            break
                    
                    if length > match_len:
                        match_len = length
                        match_offset = i - j
                        
        if match_len >= 2:
            # Token 0: Match Event
            bit_writer.write_bit(0)
            write_gamma(bit_writer, match_len - 1)
            # Commit 16-bit little endian offset
            data_stream.append(match_offset & 0xFF)
            data_stream.append((match_offset >> 8) & 0xFF)
            
            # Feed skipped sequence points back into the hash chain index
            for k in range(i, min(i + match_len, n - 1)):
                tb = (data[k] << 8) | data[k+1]
                if tb not in pos_hash:
                    pos_hash[tb] = []
                pos_hash[tb].append(k)
                if len(pos_hash[tb]) > MAX_CANDIDATES:
                    pos_hash[tb].pop(0)
                    
            i += match_len
        else:
            # Token 1: Literal Event
            bit_writer.write_bit(1)
            data_stream.append(data[i])
            
            # Feed current literal sequence point into the hash chain index
            if i + 1 < n:
                tb = (data[i] << 8) | data[i+1]
                if tb not in pos_hash:
                    pos_hash[tb] = []
                pos_hash[tb].append(i)
                if len(pos_hash[tb]) > MAX_CANDIDATES:
                    pos_hash[tb].pop(0)
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
    parser = argparse.ArgumentParser(description="Optimized BriefLZ-Style Split Stream Encoder.")
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
