#!/bin/sh
#
# (c) 2026 Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2 license
#
################################################################################

bin=uzpexec
LS=$(command -v ls)
S='Hello ($0) World!'
eof_str="U238./proc/self/exe..-f"
eof_len=$(echo "$eof_str" | wc -c)
DD() { dd status=none "$@"; }
retprt() { printf "\tret:${1:-$?}\n\n"; }
errprt() { err=$?; echo; retprt $err; }
HI() { printf '#!/bin/sh\necho "%s"\n' "$S"| gzip -c; }
do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i $bin; }
no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i $bin; }

if [ "x${1:-}" != "x-e" ]; then ################################################

if [ "x${1:-}" = "x" ]; then
  make clean $bin || { printf "nasm failed\n\n"; exit; }
else
  echo
fi

echo "Code size with EOF string:"
n=$(grep --color=never -abo "$eof_str" $bin | cut -f1 -d:)
printf "\t%d bytes\n\n" $(( ${n:--$eof_len} + $eof_len ))

echo "Strings output:"
( exec 2>&1
  echo "$(strings $bin)" | sed -e "s/^/  /" | tee /proc/self/fd/2 |
  grep -qe "([cC]) .*robang74/uzpexec v[0-9.]\{4\}" ||{
    printf "\nWARNING:\n"
    printf "\tAuthorship isn't allowed to be changed or removed"
    printf "\n\n"
    exit 1
  }
) || { make clean >&- 2>&1; exit 1; }
( exec 2>&1
  echo
  echo Binary size check:
  printf "\t%s\n" "$(du -b $bin)"

  echo
  echo "====== TESTS TO PASS (x6) ======"
  echo

  export WORLD='Hi shiny!'
  DD skip=1 if=hello.gz.sh | ./$bin wonderful | grep .
  retprt

  gzip -c $LS | ./$bin -1 ./$bin
  retprt

  do_script #####################

  echo "Shell code injection by stdin:"
  HI | zcat
  echo "- - - - - - - - - - - - - - - "
  echo

  HI | ./$bin
  retprt

  { cat $bin; HI; } > $bin.uzp &&
             chmod +x $bin.uzp
  ./$bin.uzp
  retprt

  echo "- - - - - - - - - - - - - - - "
  echo

  no_script #####################

  { cat $bin; gzip -c $LS; } | DD of=ls.gz.elf &&
  chmod +x ls.gz.elf && ./ls.gz.elf -1 ls.gz.elf
  retprt

  cat $LS | ./$bin -1 $bin
  retprt

  echo '====== TESTS !TO HANG (x10) ======'
  echo
# in case of timeout the return code is 124 or 127 not 2
  for cmd in zeroenv sigsegv; do
    ln=$(test "$cmd" = "sigsegv" && printf '\\n')
    err=${ln:+1}; err=${err:-0}
    echo "Using cmd: $cmd (ret:$err, no output)"
    cat hello | timeout 1 ./$cmd $bin >/dev/null
    retprt
  done

  if grep -q "v0\.8[0-9]" $bin; then
    for fnm in u uzp pexe xec c; do
        printf "Testing with name (ret:2) $fnm $ln"
        cp -f $bin $fnm && timeout 1 ./$fnm 2>&-
        printf "\tret:$?\n"; rm -f $fnm
    done
    echo

    fnm="pexet"
    printf "Testing with name (ret:0) $fnm $ln"
    cp -f $bin $fnm && cat hello | ./$fnm | grep Hello
    retprt; rm -f $fnm
  fi

  echo "====== TESTS FOR STDIN (x7) ======"
  echo

  echo "it runs a plain elf"
  cat $bin $LS | DD of=ls.elf &&
  chmod +x ls.elf && ./ls.elf -1 ls*
  retprt

  echo "it runs a compressed shell script"
  cat hello.sh | ./$bin | grep Hello
  retprt

  echo "it should USE 'zstdcat'"
  zstd -c hello.sh | strace -f ./$bin 2>&1 | grep "zstdcat., "  | cut -d\] -f2
  retprt

  echo "it should NOT use '-f'"
  pigz -c hello.sh | strace -f ./$bin 2>&1 | grep "cat., .-.]," | cut -d\] -f2
  retprt

  echo "it should USE 'zcat -f' with scripts"
  cat hello.sh     | strace -f ./$bin 2>&1 | grep "cat., .-f.]," | cut -d\] -f2
  retprt

  echo "it should USE 'zcat -f' with ELF bin"
  cat hello        | strace -f ./$bin 2>&1 | grep "cat., .-f.]," | cut -d\] -f2
  retprt

  echo "it FAILS in opening a closed stdin"
  ./$bin <&-
  retprt

  echo "====== ARGS TO PASS (x2) ======"

  echo
  ./uzpack -h 2>&1| grep .
  echo
  ./uzpack -v 2>&1| grep .
  echo

) | tee     tests.res
echo "====== HASH TO CHECK ======"
printf "\nTests final result: "
sha1sum     tests.res | cut -d' ' -f1 |
sed "s/452c97f7db4bc2efd236f5264dcccaad5eb43d11/$bin OK/" |
tee /proc/self/fd/2 | grep -qe " OK$" || printf "\t%s FAILED\n" $bin

################################################################################
echo;exit
################################################################################

bin=uskex
nasm -O2 -s -f bin $bin.asm -o $bin &&
chmod +x $bin && du -b $bin
# 512     uskex
cat $(which ls) >> $bin &&
./$bin -al $bin; echo $?
# -rwxrwxr-x 1 roberto roberto 138728 Jun 23 14:19 uskex
# 0

bin=uskat
nasm -O2 -s -f bin $bin.asm -o $bin &&
chmod +x $bin && du -b $bin
# 512     uskat
echo 'Hello wonderful World!' >> $bin &&
./$bin -al $bin; echo $?
# Hello wonderful World!
# 0

fi ############################################################################
