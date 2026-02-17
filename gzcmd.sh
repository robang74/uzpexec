#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# Usage: gzcmd.sh /path/elf-executable[.gz]
#

blocks=2
headstr=$(cat <<EOF
#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
# URL: raw.githubusercontent.com/robang74/bare-minimal-linux-system/
# Source: refs/heads/main/gzcmd.sh
err=1
while true; do #################################################################

ORIGNAME="$(basename ${1:-gzelf})"
cmdnme="\$0"
if [ ! -r "\$cmdnme" ]; then
  echo "ERROR: executable '\$cmdnme' is not readable"
  break
fi >&2

uzpcmd="zcat"
datens=\$(date +%N)
flenme="\$ORIGNAME"
tmp=/tmp; test -d /dev/shm/ && tmp=/dev/shm
dirnme="\$tmp/\$flenme-\$\$-\$datens"
flenme="\$dirnme/\$flenme"
mkdir -p "\$dirnme"

dd if=\$0 skip=$blocks status=none | zcat - >"\$flenme"
chmod a+x "\$flenme" && sh -c "\$flenme \$@"; err=\$?
{ rm -f "\$flenme"; rmdir "\$dirnme"; } 2>&1 | grep -q .

break; done ####################################################################
test \$err -eq 0
exit
#### ///////////////////////////////////////////////////////////////////////////
EOF
)

err=1
while true; do #################################################################

gzelf=${1:-}
if [ ! -r "$gzelf" ]; then
  echo "ERROR: executable '$gzelf' is not readable"
  break
fi >&2

gzelfle="$gzelf.gz.sh"
echo "$headstr" > $gzelfle.tmp
dd if=/dev/zero count=$blocks status=none >> $gzelfle.tmp
dd if=$gzelfle.tmp count=$blocks status=none > $gzelfle
rm -f $gzelfle.tmp

if file $gzelf | grep -q "gzip compressed data"; then
  cat $gzelf >> $gzelfle
else
  gzip -9c $gzelf >> $gzelfle
fi
err=$?
chmod +x $gzelfle
echo Size Kb: $(du -ks $gzelfle) $(file $gzelfle | cut -d: -f2-)

break; done ####################################################################
test $err -eq 0

#### ///////////////////////////////////////////////////////////////////////////
