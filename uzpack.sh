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
#if [ ${BASHPID:-0} -eq 0 ] && [ -t 0 -o -c /dev/tty ]; then exec </dev/tty; fi
 if [ ${_SETFD_:-0} -eq 0 -a -r /proc/self/fd/9 ];
   then export _SETFD_=1; . /proc/self/fd/9;
 elif [ ${BASHPID:-0} -eq 0 ] && [ -t 0 -o -c /dev/tty ];
   then exec </dev/tty;
 fi
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
cpy='(c) github/''robang74 v[^ ]* '$nme


#######################################################################
UZPAYLOAD="
H4sIAAAAAAACA31PQ+MbURCf3bzU7rm2GyeX2nYXMTevtttF7X6N2rYV3mrbvdSYF97+s5y
f3syqwaOGcBwH5eLBBKybpJI6dqiWHVpDWVVRo4Y9zxAgBKA2w5oACBtebpm+lii7Af9pR5
lyoiWfUvfvPkQ25FLqppaWG9QspNQN145H0Xpql0bqTERRSj0BOqkzftxJwgNQk7DhV0pdc
35xnfm1ulxc8Okdb/lHmwsnAEmWR3mB0fNXWW5Y8pZ7I2lt7FEgsz6lol+kREqpmoctOd+B
VInpiz/4qS+cuo5HXxvUnjxgX9L+Ln62jGr/XWE/Eze8RZFXOFGXANDGmHQ8zgFQ2PBkw9c
NH8+xVVPqOzvti4OywP195f6FgdtgtCgbl+pQiGueVpvmkzX/FpiVx4XQJ4UR2kondmB7dV
DTf/UoESgvI8jhAp0jXVonkvOVBeFec2eFQzMTLnvrhb17eiytFyydHVsci0CvcHJmr6WR0
HyoVhGMhuYphW6y1ebuMQ969IAecaix/gMt5M0cAAIAAA==
" # END_OF_UZPAYLOAD ##################################################

b64=$(command -v base64)
gzc=$(command -v pigz gzip | head -n1)

grp() { strings | command grep --color=none "$@"; }
get_copy() { grp -E "robang74|$nme" | tr '\n' ' ' | grp "$cpy"; }

st_script() {
  echo "Script mode status: '$(cat $dst |\
    grp -e "bin/.*sh")'" >&2
}
gt_plline() {
  grep --color=none -n "UZ""PAYLOAD" "$1" |\
    head -n$2 | tail -n1 | cut -d: -f1
}
gt_plbody() { dd if="${1:-$bin}" count=1 status=none; }
dd_zcarry() { dd if="${1:-$bin}"  skip=1 status=none; }
dd_gtcopy() { gt_plbody ${1:-$bin} | get_copy ; }
dd_gtpack() { dd_gtcopy ${1:-$bin} | grep -q .; }
dd_gtuzip() { dd_zcarry ${1:-$bin} | $gzc -dc ; }

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
if prt_versn |  grep -qe " v0\.8[0-9] "; then
    do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i "$dst"; }
    no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i "$dst"; }
else
    do_script() { true; }
    no_script() { true; }
fi

# Parse arguments
case "${1:-}" in
  -v|--version)
      prt_versn
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
    if [ "$spt" -eq 0 ]; then
        no_script
        st_script
        printf "Compressing a binary ... " >&2
    else
        do_script
        st_script
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
