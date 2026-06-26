#!/bin/sh
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2 license
#
# Description:
#
#   Wrapper to package binaries or shell scripts into a self-extracting
#   executable package using uzpexec as the micro-stub loader.
#
################################################################################

# ------------------------------------------------------------------------------
if [ -t 0 ] || [ -c /dev/tty ]; then exec </dev/tty; fi
# ------------------------------------------------------------------------------

usage() {
    echo
    echo "Usage: uzpack [-h|--help] [-v|--version]"
    echo "       uzpack [-s|--script] origin.elf [destination.uzp]"
    echo
}

do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i "$dst"; }
no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i "$dst"; }
st_script() { echo "script mode status: $(strings $dst | grep bin/sh)"; }
dd_gtpack() { dd if="${1:-}" count=1 status=none | grep -qe "robang74 .* uzpexec"; }

spt=0
ext=0
gzc=$(command -v pigz gzip | head -n1)
bin=$(command -v uzpexec || echo ./uzpexec)
b64=$(command -v base64)

prt_versn() { { ${1:-$bin} <&- || echo; } 2>&1 | tr '\0' '\n' | grep -vi bad; }

# RAF, TODO: enable the Makefile to update this embedded payload
#######################################################################
UZPAYLOAD="
H4sIAAAAAAACA01PA7fcUBCeZKO6Pa5tBrVtK6iZZ5vrvYtf0YP6sLZt27aNmfJdDz7ciuH
jRnAcB38HDx6gaFqloBjwfxjQDP52/evGHtpfMCEIADLl6gKY7H4iNSTEmvTy5E6ewa6z16
v7dc3j2evAzrx37PyOPV5BWb02T8bw45wnXeeoh5JF81glO7BJ8AnKZvQAyR6TfTlWGdxZJ
/IcSesEHuLZfnfegye8+mMLEdRZP7Vx4HRevY2LUD2Zs45VLgNEP6mR3MHcQjxTj1Um8yZx
5LqB07mqnSyZMVvA7EAz1kA9hI8a5pabSHVAaPURr8S4Vh/dd/iYyh4fq3xSpB5ST6tXxib
LRPIjV0Y8edq4BAVjjUksGdgt9po930G/RsgIpGZfiPp3HWWlWGMFX1gYTFYKW5LoES9h3U
94BX/kie4zfLiUZLfU0+irhZ0smMm8s2kF5jDm0EG7he2bLU3KdfMWdM3OWDA/fWlPo1l+t
y69jGZ5xZmLCxcvhK4LktK7Fi+cnwtVByVz3N/vzksApmt6r8450Lnz79RPy5be4gACAAA=
" # END_OF_UZPAYLOAD ##################################################

echo
echo "uzpack args_v[$#]: $0 '$@'"

while true; do
    # Parse arguments
    case "${1:-}" in
        -v|--version)
            prt_versn "$bin"
            shift
            ext=1
            ;;
        -h|--help)
            usage
            shift
            ext=1
            ;;
        -s|--script)
            shift
            spt=1
            ;;
    esac
    test $ext -eq 0 || break

    if [ ! -x "$gzc" ]; then
        echo "Error: Neither pigz nor gzip is available or executable." >&2
        break
    fi

    if [ "x${1:-}" = "x" ]; then
        echo "Error: No arguments" >&2
        usage
        break
    fi

    src="${1:-}"
    if [ -z "$src" ] || [ ! -r "$src" ]; then
        echo "Error: Target payload file '$src' is missing or unreadable." >&2
        usage
        break
    fi

    dst="${2:-$(basename $src).uzp}"

    if dd_gtpack "$src"; then
        echo "Warning: file '$src' was already converted, just copy." >&2
        command cp -i "$src" "$dst"
        break
    fi

    # Safely copy the uzpexec binary stub to the destination path
    if [ "$bin" != "" ]; then
        echo
        command cp -i "$bin" "$dst" || {
            echo "Error: Failed to copy the binary stub to '$dst'." >&2
            break
        }
        #echo
    elif [ "$UZPAYLOAD" != "" -a "$b64" != "" ]; then
        echo "Warning: 'uzpexec' not found, using $UZPAYLOAD base64"
        echo "$UZPAYLOAD" | $b64 -d | $gzc -dc >uzpex || {
            echo "Error: Failed to copy the binary stub to '$dst'." >&2
            break
        }
    else
        echo "Error: Failed to find the 'uzpexec' payload"
        break
    fi

    # Alter internal routing tags inside the stub depending on carryload type
    if [ "$spt" -eq 0 ]; then
        no_script
        st_script
        printf "Compressing a binary ... "
    else
        do_script
        st_script
        printf "Compressing a script ... "
        # RAF, TODO: add sanity check for the script (cfr. universal template)
    fi

    # Append the compressed payload onto the newly built self-extracting file
    $gzc -c "$src" >> "$dst" || {
        printf "KO\n\n"
        echo "Error: Payload compression or concatenation failed." >&2
        break
    }
    printf "OK\n\n"

    # Enforce safe execution permissions over the generated package
    chmod +x "$dst" || {
        echo "Error: Could not make target '$dst' executable." >&2
        break
    }

    echo "Successfully generated: $dst" # $(du -b "$dst")
#   command ls -l "$dst"
    echo
    break
done

# ------------------------------------------------------------------------------
exit
# ------------------------------------------------------------------------------
