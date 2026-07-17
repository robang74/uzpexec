#!/bin/sh
# (c) Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
# This is a busybox compatible script, and it fails at the first error
set -e
bin=${1:-}
test -r "$bin"

# busybox sed isn't able to deal with binary files, so hexdump
hexdump -v -e '1/1 "%02x"' uzpexec > ${bin}.hex
# converts the '/bin/sh.{5}' string into '/bin/python3' string
sed -i 's/2f62696e2f73680000000000/2f62696e2f707974686f6e33/g' ${bin}.hex
# check the string conversion took place effectively in hexfile
grep -q "2f62696e2f707974686f6e33" ${bin}.hex
# awk is the general solution, the xxd use can be dropped here
xxd -r -p ${bin}.hex >${bin}z 2>&- || 
  awk '{ printf("%c", strtonum("0x" $1)) }' ${bin}.hex >${bin}z
# grepping the binary file is expected to work always, anyway
{ stringz ${bin}z 2>&- || { cat ${bin}z | tr -cd [a-z]; }; } |
  grep -q python3 && rm -f ${bin}.hex
# python scripts are relatively short text file, -11c is fine
gzip -11c ${bin} >> ${bin}z && chmod +x ${bin}z
# it shows the difference in size between original vs output
du -b ${bin} ${bin}z
