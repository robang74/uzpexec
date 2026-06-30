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
if [ ! -n "${BASH_VERSION:-}" ]&&[ -t 0 -o -c /dev/tty ];then exec < /dev/tty;fi
# RAF, TODO: for testing the console ## read -p "proceed with '$-' ? " xp  # <&3
# ------------------------------------------------------------------------------

usage() {
    echo
    echo "Usage: uzpack [-h|--help] [-v|--version]"
    echo "       uzpack origin [destination[.uzp]]"
    echo "       uzpack [-x: debug | -1/-11: gzip]"
}

lvl=
spt=0
ext=0
upd=0
ret=0
rpl=0
emb=0

nme="uzpexec"
cpy='(c) github/''robang74 .*[ \\n]'$nme

#######################################################################
UZPAYLOAD="
H4sIAAAAAAACA6t39XFjZGRkgAEmBmYGEC+kgYXDhAEBTBgUGGCq4KqBakD4FVCAhYWBgR0
kJsDAENH5rDenjaVbLqzz3pqWA6W/e8t+7d/SyMKxPC68xLjBmqHkp+HJLNaIsw2dx3eyNL
Fw7AJay5DFHNH5+2xD6wH+jqdAc/hb7gNJzUOlz18zGf6P5t8WLN5yqVRwRwojUClj5NmGx
QxAna+5s7QidoPMCD7bkMUUAdJfktFyqcQwKostojuKBShqH9EtZXgSyOCO2H0e6IrjLCpP
gFSvj8qPjIdARnDnq7MNr0sMTxpeMrztncUOMuR/CXsWG9g9O9KAFnbLgizLYuh82Pmp891
+kCeBWhyz7IFKQEZD5IHWsnXLcgBZQAlHkFMq5ECW7moE6W39X8qa8RzIzADxOx8aXgI6SS
lq5wwg75iL4H+uLJaILKZooCAj0AUayZoK6ZklGaVJ+kX5SYl56eYmCmUGehbmCqVVBakVq
ckM+kmZefpVyYklDMgAJFicAeWEGhlb6BYz6Ooy6KYxYAcAIpLmlwACAAA=
" # END_OF_UZPAYLOAD ##################################################

b64=$(command -v base64)
gzc=$(command -v pigz gzip | head -n1)

do_script() { /bin/sed -e 's,\x00\(bin/sh\),/\1,' -i "${1:-$dst}"; }
no_script() { /bin/sed -e 's,/\(bin/sh\),\x00\1,' -i "${1:-$dst}"; }
st_script() { echo "Script mode status: '$(strings $dst | grep bin/sh)'" ; }
gt_plline() { grep -n "UZ""PAYLOAD" "$1" | head -n$2 | tail -n1 | cut -d: -f1; }
gt_plbody() { dd if="${1:-$bin}" count=1 status=none; }
dd_zcarry() { dd if="${1:-$bin}"  skip=1 status=none; }
dd_gtcopy() { gt_plbody ${1:-$bin} | strings | grep -e "$cpy"; }
dd_gtpack() { dd_gtcopy ${1:-$bin} | grep -q .; }
dd_gtuzip() { dd_zcarry ${1:-$bin} | $gzc -dc; }

# ==============================================================================
# SHELL SCRIPT COMMANDS EXECUTION -- ABOVE ONLY DEFINITIONS
# ==============================================================================

# RAF: for debug, and run-time inspectability
case "${1:-}" in
  -q) exec 2>&-
      shift
      ;;
  -x) set -x
      shift
      ;;
  +x) set +x
      shift
      ;;
esac

bin=$(command -v $nme || echo ./$nme)
if [ ! -r "$bin" ]; then
    d=$(dirname "$0")
    bin="${d:-.}/$nme"
fi
if [ -r "$bin" ]; then
    prt_versn() { echo; dd_gtcopy; }
else
    emb=1
   _gt_plbody() { echo "$UZPAYLOAD" | $b64 -d | $gzc -dc; }
    prt_versn() { echo; _gt_plbody | strings | grep -e "$cpy"; }
    echo "Notice: '$nme' not found, using UZPAYLOAD base64" >&2
fi

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
  -[0-9]|-11)
      lvl=$1
      shift
      ;;
  -s|--script)
      echo "WARNING: option '-s' enforces the script mode (dev onnly)" >&2
      shift
      spt=1
      ;;
  -u|--update)
      echo "WARNING: option '-u' updates the script payload (dev onnly)" >&2
      shift
      upd=1
      ;;
esac

while [ $ext -eq 0 ]; do
    {
      echo
      echo "Running uzpack argc: $#, argv: $0"
      echo "    src: '${1:-}'"
      echo "    dst: '${2:-}'"
    } >&2

    if [ "$gzc" = "" ]; then
        echo "ERROR: neither pigz nor gzip is available in path." >&2
        ret=1; break
    fi
    printf "Notice: using '%s' compression level" "$(basename "$gzc")"  >&2
    printf "set to '$lvl' (default: '${GZIPLVL:-}')\n"  >&2

    if [ $upd -ne 0 ]; then
        test -r "${1:-}" && bin="$1"
        if [ ! -r "${bin}" ]; then
            echo "ERROR: '$nme' not found, updating embedded payload failed" >&2
            ret=1; break
        fi
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
        break
    fi

    if [ "x${1:-}" = "x" ]; then
        echo "ERROR: no arguments" >&2
        usage
        ret=1; break
    fi

    src="${1:-}"
    if [ -z "$src" -o ! -r "$src" ]; then
        echo "ERROR: target file '$src' is missing or unreadable." >&2
        usage
        ret=1; break
    fi

    if dd_gtpack "$src"; then
        echo "Notice: file '$src' was already converted, updating." >&2
        rpl=1
    fi

    if [ $spt -eq 0 ]; then
        if [ $rpl -eq 0 ]; then
            shb=$(head -c2 "$src")
        else
            shb=$(dd_gtuzip "$src" | head -c2)
        fi
        test "$shb" = '#!' && spt=1
    fi

    dst="${2:-$(basename $src).uzp}"

    # Safety check about the destination filename to avoid argv[0] underflow
    bdst=$(basename "$dst")
    if ! printf "%s" "$bdst" | grep -qe ".\{5\}$"; then
        echo "WARNING: destination filename '$bdst' too short, min 7" >&2
    fi

    # Safely copy the uzpexec binary stub to the destination path
    if [ -r "$bin" ]; then
        command cp -f "$bin" "$dst" || {
            echo "ERROR: failed to copy the binary stub to '$dst'." >&2
            ret=1; break
        }
    elif [ "$UZPAYLOAD" != "" -a "$b64" != "" ]; then
        echo "$UZPAYLOAD" | $b64 -d | $gzc -dc > "$dst" || {
            echo "ERROR: failed to copy the binary stub to '$dst'." >&2
            ret=1; break
        }
    else
        echo "ERROR: failed to find the '$nme' payload" >&2
            ret=1; break
    fi

    # Alter internal routing tags inside the stub depending on carryload type
    if [ $spt -eq 0 ]; then
        no_script
        st_script 
        printf "Compressing a binary ... " >&2
    else
        do_script
        st_script | tee /proc/self/fd/2 | grep -qe "/bin/sh" || {
            echo "ERROR: sed did not its job correctly, failed"
            break
        }
        printf "Compressing a script ... " >&2
        # RAF, TODO: add sanity check for the script (cfr. universal template)
    fi

    # Append the compressed payload onto the newly built self-extracting file
    _l1_cmd() { $gzc -c "$@"; }
    if [ $rpl -eq 0 ]; then
        _l2_cmd() { _l1_cmd ${lvl:-${GZIPLVL:-}} "$@"; }
    elif [ -n "$lvl" ]; then
        _l2_cmd() { dd_gtuzip "$@" | _l1_cmd $lvl; }
    else
        _l2_cmd() { dd_zcarry "$@"; }
    fi
    { _l2_cmd "$src" >> "$dst"; } ||
    {
        echo "KO"
        echo
        echo "ERROR: conversion failed."
        ret=1; break
    } >&2
    { echo "OK"; echo; } >&2
    if [ "$rpl" -ne 0 ]; then
        val="identical"
        diff "$src" "$dst" >/dev/null || val="different"
        echo "Update: source and destination are $val" >&2
    fi

    # Enforce safe execution permissions over the generated package
    chmod +x "$dst" || {
        echo "WARNING: can not make target '$dst' executable." >&2
        break
    }

    echo "Successfully generated: $dst"
    # $(du -b "$dst")
    # command ls -l "$dst"
    break
done
test $ret -eq 0 || rm -f "$dst"
echo >&2
# ------------------------------------------------------------------------------
exit $ret
# ------------------------------------------------------------------------------
