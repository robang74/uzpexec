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
    echo "       uzpack origin [destination[.uzp]]"
    echo
}

spt=0
ext=0
upd=0

gzc=$(command -v pigz gzip | head -n1)
bin=$(command -v uzpexec || echo ./uzpexec)
b64=$(command -v base64)

cpy='(c) github/''robang74 .* uzpexec'

do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i "$dst"; }
no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i "$dst"; }
st_script() { echo "script mode status: $(strings $dst | grep bin/sh)"; }
dd_gtpack() { dd if="${1:-}" count=1 status=none | grep -qe "$cpy"; }
gt_plline() { grep -n "UZ""PAYLOAD" "$1" | head -n$2 | tail -n1 | cut -d: -f1; }
prt_versn() { { ${1:-$bin} <&- || echo; } 2>&1 | tr '\0' '\n' | grep -vi bad; }

# RAF, TODO: enable the Makefile to update this embedded payload
#######################################################################
UZPAYLOAD="
H4sIAAAAAAACA6t39XFjZGRkgAEmBmYGEC+kgYXDhAEBTBgUGGCq4KqBakD4HVCAhYWBgR0
kJsDAENH5rDenjaVbzoK5xDms896algOlv3vLfu3f0cjCsTwuvETP8GQWa8TZhs7jO1maWD
h2AW1lyGKO6Px9tqH1AH/HK6Ax/C1PgKTmodLnr5kM/0fzbwsWb7lUKrgjhRGolDHybMNiB
qDO19xZWhG7QWYEn23IYooA6S/JaLlUYhiVxRbRHcUCFLWP6JYyPAlkcEfsvgx0wHEWlddA
qtdH5UfGCyAjuPPV2YbXlYYnDS8Z3vbOYgcZ8r+EPYsN7J4daUALu2VBlmUxdD7s/NT5bj/
Ij0Atbln2QCUgoyHyQGvZumU5gCyghCPIKRXKIEv3NYL0ZrwBUq3/S1kzHgAZGSDBzoeGl4
DuUoraOQfIO+Yi+J8riyUiiykaKMgIdIZGsqZCemZJRmmSflF+UmJeurmJQpmBnoWZQmlVQ
WpFajKDflJmnn5VcmIJAzIACRZnQNi6aQwMoUbGFrrFDLq6DJgAAMaqVg0AAgAA
" # END_OF_UZPAYLOAD ##################################################

echo
echo "uzpack argc: $#, argv: $0 '$@'"

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
            echo "Warning: option '-s' enforces the script mode (dev onnly)"
            shift
            spt=1
            ;;
        -u|--update)
            shift
            upd=1
            ;;
    esac
    test $ext -eq 0 || break

    if [ ! -x "$gzc" ]; then
        echo "Error: neither pigz nor gzip is available or executable." >&2
        break
    fi

    if [ $upd -ne 0 ]; then
        test -r "${1:-}" && bin="$1"
        test -r "${bin}" || break
        srt=$(gt_plline "$0" 1)
        end=$(gt_plline "$0" 2)
        test $end -gt $srt || break
        hf1=$(cat "$0" | head -n  $srt)
        end=$((end-1))
        hf2=$(tac "$0" | head -n -$end | tac)
        pld=$(pigz -11nmOc $bin | base64 -w 71)
        printf "%s\n%s\n%s\n" "$hf1" "$pld" "$hf2" >"$0".tmp
        trap "mv -f '$0'.tmp '$0'" EXIT
        echo "Successfully updated: $bin --> $0"
        echo
        break
    fi

    if [ "x${1:-}" = "x" ]; then
        echo "Error: no arguments" >&2
        usage
        break
    fi

    src="${1:-}"
    if [ -z "$src" ] || [ ! -r "$src" ]; then
        echo "Error: target file '$src' is missing or unreadable." >&2
        usage
        break
    fi

    if [ $spt -eq 0 ]; then
        shb=$(head -c2 "$src")
        test "$shb" = '#!' && spt=1
    fi
    dst="${2:-$(basename $src).uzp}"

    # Safety check about the destination filename to avoid argv[0] underflow
    bdst=$(basename "$dst")
    if printf "%s" "$bdst" | grep -qe ".\{7\}$"; then
        echo "Error: destination filename '$bdst' too short, min 7"
        break
    fi

    if dd_gtpack "$src"; then
        echo "Warning: file '$src' was already converted, just copy." >&2
        command cp -i "$src" "$dst"
        break
    fi

    if dd_gtpack "$src"; then
        echo "Warning: file '$src' was already converted, just copy." >&2
        command cp -i "$src" "$dst"
        break
    fi

    # Safely copy the uzpexec binary stub to the destination path
    if [ "$bin" != "" ]; then
        echo
        command cp -i "$bin" "$dst" || {
            echo "Error: failed to copy the binary stub to '$dst'." >&2
            break
        }
        #echo
    elif [ "$UZPAYLOAD" != "" -a "$b64" != "" ]; then
        echo "Warning: 'uzpexec' not found, using $UZPAYLOAD base64"
        echo "$UZPAYLOAD" | $b64 -d | $gzc -dc >uzpex || {
            echo "Error: failed to copy the binary stub to '$dst'." >&2
            break
        }
    else
        echo "Error: failed to find the 'uzpexec' payload"
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
        echo "Error: conversion failed." >&2
        break
    }
    printf "OK\n\n"

    # Enforce safe execution permissions over the generated package
    chmod +x "$dst" || {
        echo "Error: can not make target '$dst' executable." >&2
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
