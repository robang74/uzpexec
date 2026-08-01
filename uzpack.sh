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
#if [ ${BASHPID:-0} -eq 0 ] && [ -t 0 -o -c /dev/tty ]; then exec < /dev/tty; fi
# RAF, TODO: for testing the console ## read -p "proceed with '$-' ? " xp  #<&3
# ------------------------------------------------------------------------------

usage() {
    echo
    echo "Usage: uzpack [-h|--help] [-v|--version]"
    echo "       uzpack origin [destination[.uzp]]"
    echo "       uzpack [-x: debug | -1/-19: pigz]"
    echo " export UZCMD=[zstd | (any other ztool)]"
}

lvl=
spt=0
ext=0
upd=0
ret=0
rpl=0
emb=0
old=0
opt=nc

nme="uzpexec"
cpy='(c) github/''robang74.'$nme' v[^ ]* '


################################################################################
UZPAYLOAD="
H4sIAAAAAAAAA6t39XFjZGRkgAEmBmYGEC+kgYXDhAEBTBgUGGCq4KqBakD4G0hAgIGBnQFCR3Q+681p
Y8lSi85ijDQ8MHPDmrMNG9ZsZvE825DFGrH7WSMLR/BOBgYOhrMNnce3MG5Iaf1Wotctl8UcebYhAMQH
UlnCEZ2/tzJtBKrJYgYydzI0sXBsYjnbYHmhhKP1f0mA4f/Xz9IaLZUVS1SBVL1riRyQ0thaIt1g+who
QWipULfoDSCjU/QqkHzNEh0VHBwd3HkoiyXibMMmhm18nb+BBp9taD1QwlbB9PrJa/+ZhiejNwifbYiI
Ou7EnZaibxkUYHm4lNn7NccGJrA6ryz2CMPb3oaXzjY0H2Ap+ZgVExG9lWUj5yb+sw2vhTbYZ3ECPbCB
G2hT56vXEq8tdqQBAyaLofNh56fOd2n7GQSAZr++0cuj8lp2g/1GTqBa++iNjGcbPEp5o7MYgptfiwd3
Ppy5gRvoZZaILMbonauALs9SjQIqBKrSSNZUSM8syShN0i/KT0rMSzc30S+tKkitSE1WKDPQs7TQM1Lg
0k/KzNOvKi5JSU4sgUZSqJGxhX5BUX6yfnFqTpo+UD1StDIAAIsUk6IAAgAA
" # END_OF_UZPAYLOAD ###########################################################

b64=$(command -v base64)
zct=$(command -v zcat | head -n1)
gzc=$(command -v ${UZCMD:-} pigz zopfli gzip zstd | head -n1)

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

# Parse arguments
case "${1:-}" in
  -u|--update)
      msg="option '-u' updates the script payload"
      printf "\nWARNING: %s\n" "$msg" >&2
      gzc=$(command -v pigz zopfli gzip | head -n1)
      shift
      lvl=-19
      upd=1
      ;;
esac

bin=$(command -v $nme || echo ./$nme)
if [ ! -r "$bin" ]; then
    d=$(dirname "$0")
    bin="${d:-.}/$nme"
fi
# It should always relies on the internal uzpexec, unless updating
if [ ${upd:-0} -ne 0 -a -r "$bin" ]; then
    prt_versn() { echo; dd_gtcopy; }
else
    emb=1
   _gt_plbody() { echo "$UZPAYLOAD" | $b64 -d | $zct; }
    prt_versn() { echo; _gt_plbody  | strings | grep -e "$cpy"; }
fi
if prt_versn |  grep -qe " v0\.8[0-9] "; then
    do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i "$dst"; }
    no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i "$dst"; }
    old=1
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
  -[0-9]*)
      lvl=$1
      shift
      ;;
  -s|--script)
      echo "WARNING: option '-s' enforces the script mode (dev onnly)" >&2
      shift
      spt=1
      ;;
esac

# The standard gzip hasn't -11 but pigz
echo "$gzc$lvl"  | grep -q "gzip-1[0-9]" && lvl="-9"
# zopli doesn't support nor need '-n'
echo "$gzc-$opt" | grep -q "zopfli-nc" && opt="c"
# pigz hasn't -10 or -12+ use -11
echo "$gzc$lvl"  | grep -q "pigz-1[0,2-9]" && lvl="-11"
# pigz allows -m to not store the date
echo "$gzc-$opt" | grep -q "pigz-nc" && opt="nmc"

while [ $ext -eq 0 ]; do
    if [ $upd -eq 0 ]; then
      echo
      echo "Running uzpack argc: $#, argv: $0"
      echo "    src: '${1:-}'"
      echo "    dst: '${2:-}'"
    fi >&2

    if [ "$gzc" = "" ]; then
        echo "ERROR: no suitable compressor is available in path." >&2
        ret=1; break
    fi
    printf "Notice: using '%s -%s' compression level" "$(basename "$gzc")" $opt >&2
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
        pld=$($gzc -$opt $bin | $b64 -w 80)
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
    if [ $old -eq 1 ]; then
        bdst=$(basename "$dst")
        if ! printf "%s" "$bdst" | grep -qe ".\{5\}$"; then
            echo "WARNING: destination filename '$bdst' too short, min 7" >&2
        fi
    fi

    # Safely copy the uzpexec binary stub to the destination path
    if [ ${upd:-0} -ne 0 -a -r "$bin" ]; then
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
    _l1_cmd() { $gzc -$opt "$@"; }
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
