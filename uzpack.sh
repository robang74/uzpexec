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

prt_versn() { { ${1:-$bin} <&- || echo; } 2>&1 | tr '\0' '\n' | grep -vi bad; }

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
    echo
    command cp -i "$bin" "$dst" || {
        echo "Error: Failed to copy the binary stub to '$dst'." >&2
        break
    }
#   echo

    # Alter internal hardware routing tags inside the stub depending on payload type
    if [ "$spt" -eq 0 ]; then
        no_script
        st_script
        printf "Compressing a binary ... "
    else
        do_script
        st_script
        printf "Compressing a script ... "
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
