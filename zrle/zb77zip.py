#!/usr/bin/env python3
# ==============================================================================
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# ==============================================================================

import sys
import argparse

class BitWriter:
    def __init__(self):
        self.words = bytearray()
        self.current_word = 0
        self.bit_count = 0

    def write_bit(self, bit):
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
    binary = bin(val)[2:]
    k = len(binary) - 1
    for _ in range(k):
        bit_writer.write_bit(0)
    for bit in binary:
        bit_writer.write_bit(1 if bit == '1' else 0)

def find_best_match(data, i, pos_hash, window_size, max_candidates):
    n = len(data)
    match_offset = 0
    match_len = 0

    if i + 1 < n:
        two_bytes = (data[i] << 8) | data[i+1]
        if two_bytes in pos_hash:
            candidates = pos_hash[two_bytes]
            count = 0
            for j in reversed(candidates):
                if i - j > window_size:
                    break

                length = 2
                while i + length < n and data[j + length] == data[i + length]:
                    length += 1
                    if length == 65535:
                        break

                if length > match_len:
                    match_len = length
                    match_offset = i - j

                count += 1
                if count >= max_candidates:
                    break

    return match_offset, match_len

def compress_brieflz_style(data, level):
    bit_writer = BitWriter()
    data_stream = bytearray()

    i = 0
    n = len(data)
    window_size = 65535
    pos_hash = {}

    # Configurazione dinamica dei parametri in base al livello
    # Livelli 1-3: Molto veloci, catena corta
    # Livelli 4-6: Bilanciati, catena media
    # Livelli 7-9: Massimi, catena profonda + Lazy Parsing attivato
    max_candidates_map = [0, 4, 16, 32, 64, 128, 256, 512, 1024, 2048]
    max_candidates = max_candidates_map[level]
    lazy_parsing = True if level >= 7 else False

    while i < n:
        match_offset, match_len = find_best_match(data, i, pos_hash, window_size, max_candidates)

        # Ottimizzazione Lazy Matching (Livelli Alti)
        if match_len >= 2 and lazy_parsing and (i + 1 < n):
            # Inseriamo momentaneamente il punto corrente per simulare la catena di hash successiva
            tb_curr = (data[i] << 8) | data[i+1]
            if tb_curr not in pos_hash:
                pos_hash[tb_curr] = []
            pos_hash[tb_curr].append(i)

            # Controlliamo se il byte successivo offre un match migliore
            _, next_len = find_best_match(data, i + 1, pos_hash, window_size, max_candidates)

            # Ripristiniamo lo stato precedente dell'hash
            pos_hash[tb_curr].pop()
            if not pos_hash[tb_curr]:
                del pos_hash[tb_curr]

            # Se il match successivo è strettamente migliore, saltiamo questo match optando per un letterale
            if next_len > match_len:
                match_len = 0

        if match_len >= 2:
            # Token 0: Match Event
            bit_writer.write_bit(0)
            write_gamma(bit_writer, match_len - 1)
            data_stream.append(match_offset & 0xFF)
            data_stream.append((match_offset >> 8) & 0xFF)

            # Popoliamo l'indice hash per la sequenza saltata
            for k in range(i, min(i + match_len, n - 1)):
                tb = (data[k] << 8) | data[k+1]
                if tb not in pos_hash:
                    pos_hash[tb] = []
                pos_hash[tb].append(k)
                if len(pos_hash[tb]) > max_candidates * 2:
                    pos_hash[tb].pop(0)

            i += match_len
        else:
            # Token 1: Literal Event
            bit_writer.write_bit(1)
            data_stream.append(data[i])

            if i + 1 < n:
                tb = (data[i] << 8) | data[i+1]
                if tb not in pos_hash:
                    pos_hash[tb] = []
                pos_hash[tb].append(i)
                if len(pos_hash[tb]) > max_candidates * 2:
                    pos_hash[tb].pop(0)
            i += 1

    # Fine dello stream (EOS)
    bit_writer.write_bit(0)
    write_gamma(bit_writer, 1)
    data_stream.append(0)
    data_stream.append(0)

    bit_writer.flush()

    tag_stream = bit_writer.words
    tag_size = len(tag_stream)

    header = tag_size.to_bytes(4, byteorder='little')
    return header + tag_stream + data_stream

def main():
    parser = argparse.ArgumentParser(description="BriefLZ-Style Encoder con livelli di compressione.")
    parser.add_argument("-l", "--level", type=int, choices=range(1, 10), default=4,
                        help="Livello di compressione: 1 (rapido), 9 (massimo, default: 4)")
    parser.add_argument("input", help="File di input")
    parser.add_argument("output", help="File di output (o '-' per stdout)")
    args = parser.parse_args()

    try:
        with open(args.input, 'rb') as f:
            input_data = f.read()
    except IOError as e:
        print(f"Errore in lettura: {e}", file=sys.stderr)
        sys.exit(1)

    compressed_data = compress_brieflz_style(input_data, args.level)

    try:
        if args.output == '-':
            sys.stdout.buffer.write(compressed_data)
            sys.stdout.buffer.flush()
        else:
            with open(args.output, 'wb') as f:
                f.write(compressed_data)
    except IOError as e:
        print(f"Errore in scrittura: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
