#!/usr/bin/env python3
# ==============================================================================
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# ==============================================================================

import sys
import lz4.block

# Read input file (binary)
with open(sys.argv[1], 'rb') as f:
    data = f.read()

# Compress using raw block mode
compressed = lz4.block.compress(data, store_size=False)

# Write to stdout
sys.stdout.buffer.write(compressed)
