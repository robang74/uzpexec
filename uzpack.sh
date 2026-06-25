#!/bin/sh
#
# (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2 license
#
# $description
# 
################################################################################

usage() {
echo
echo uzpack [-h|--help] [-v|--version] 
echo uzpack [-s|--script] origin.elf [destination.uzp]
}

do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i $dst; }
no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i $dst; }

scr=0
gzc=$(command -v pigz gzip)
bin=$(command -v uzpexec || echo ./uzpexec)

prt_versn() { ${1:-$bin} <&-||echo; }


do {
test -x "$gzc" || break

case -v or --version) uzpexec <&-||echo; break
case -h or --help) head $0; break
case -s or --script) scr=1; shift

src=${1:-}
test -r $sr || break

dst=${2:-$src.uzp}
command cp -i $bin $dst || break

if [ $scr -eq 0 ]; then
  no_script
  printf "\nCompressing a binary ..."
else
  do_script
  printf "\nCompressing a script ..."
fi

$gzc -c $src >> $dst ||{
  printf "KO\n\n"
  break
}
printf "OK\n\n"
prt_versn $dst
du -k $dst

} while(0)
