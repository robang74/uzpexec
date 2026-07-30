UZPACK(1)                        User  Commands                        UZPACK(1)

NAME

   uzpack - package binaries or scripts into self-extracting ELF32 executables

SYNOPSIS

   uzpack [-h|--help] [-v|--version]
   uzpack [-s|--script] [-u|--update] [-n|-1:-19] origin [destination[.uzp]]

DESCRIPTION

   uzpack is a wrapper utility that converts a binary executable or a shell
   script into a self-extracting, self-running ELF32 file using the uzpexec(1)
   micro-stub loader. The resulting file carries a 512-byte payload header
   (the uzpexec extractor) followed by a compressed copy of the original file.
   When executed, the stub decompresses the payload entirely in RAM (via
   memfd_create(2)) and runs it without writing to disk.

   The default compression tool is gzip(1); this can be overridden at run-time
   via the UZCMD environment variable (e.g. with zstd, pigz, or zopfli). The
   default output name is derived from the basename of origin with the .uzp
   extension appended. If destination is given, it is used as-is; the .uzp
   extension is conventional but not mandatory.

OPTIONS

   -h, --help
      Display a brief usage summary and exit.

   -v, --version
      Print the version string embedded in the uzpexec stub and exit.

   -s, --script
      Force script mode. The internal stub is patched so that the payload
      is interpreted by /bin/sh rather than executed as a raw binary. If
      the input file begins with a shebang (#!), this mode is selected
      automatically.

   -u, --update
      Update the embedded uzpexec payload inside the uzpack script itself.
      This is primarily used during development when a new uzpexec binary
      is available.

   -n Set the compression level n passed to the underlying compressor
      (honoured by gzip, pigz, and zstd). When UZCMD selects zstd, levels
      up to 19 can be used.

ENVIRONMENT

   UZCMD Select an alternative compression program. If unset, uzpack searches
   for zstd, pigz, zopfli, and gzip in that order.

NOTES

 Origin and Form

   The command uzpack is normally distributed as a compiled ELF32 binary
   produced from the accompanying uzpack.sh shell script. The shell script
   is the canonical source form; the ELF32 binary is the derived, ready-to-run
   form. Both forms behave identically from the user's perspective.

 Supported formats

   The uzpexec stub natively supports gzip and zstd payloads. The decompressor
   path stored in the stub can be customised with sed(1) to target non-standard
   installations (e.g. /usr/local/bin/zstdcat). See the project README for the
   exact byte layout and safe sed patterns.

 Inspecting Contents

   Because the .uzp file consists of a 512-byte uzpexec stub followed
   immediately by compressed data, the payload can be inspected without
   execution:

      dd skip=1 if=package.uzp | zcat
      dd skip=1 if=package.uzp | zstdcat

   This is a simple and quick way to verify the contents of a converted file.

 Script Compatibility

   When  packaging a shell script, the input should contain a properly set
   shebang line (e.g., #!/bin/sh). A universal template recommended for full
   compatibility is:

      #!/bin/sh
      # put your shell script code here
      exit

EXAMPLES

   Convert a binary executable with default settings:

      uzpack /usr/local/bin/myapp myapp.uzp

   Convert using zstd level 19:

      UZCMD=zstd uzpack -19 myapp myapp.uzp

   Convert a shell script (auto-detected by shebang):

      uzpack deploy.sh

   Convert the uzpack script itself into its own binary form:

      sh uzpack.sh -s uzpack.sh uzpack

SEE ALSO

   uzpexec(1), gzip(1), zcat(1), zstd(1), zstdcat(1), memfd_create(2), dd(1)

AUTHOR

   Roberto A. Foglietta <roberto.foglietta@gmail.com>

COPYRIGHT

   Text and documentations are published under CC BY-NC-ND 4.0. The ELF32
   binary payload is licensed under MIT+1 clause terms. The script is
   licensed under the GNU General Public License version 2 (GPLv2).

v0.98                            2026-07-29                            UZPACK(1)
