#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license

headstr=$(cat <<EOF
#!/bin/sh -x
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license

err=1
echo "0: \$0 ; args: \$@"
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
dirnme="/tmp/\$flenme-\$\$-\$datens"
flenme="\$dirnme/\$flenme"
mkdir -p "\$dirnme"

dd if=\$0 skip=2 status=none | zcat - >"\$flenme"
chmod a+x "\$flenme" && sh -c "\$flenme \$@"
err=\$? #; rm -f "\$flenme"

break; done ####################################################################
test \$err -eq 0
exit
#### ///////////////////////////////////////////////////////////////////////////
EOF
)
#echo "$headstr"

err=1
while true; do #################################################################

gzelf=${1:-}
if [ ! -r "$gzelf" ]; then
  echo "ERROR: executable '$gzelf' is not readable"
  break
fi >&2

gzelfle="$gzelf.gz.sh"
echo "$headstr" > $gzelfle.tmp
dd if=/dev/zero count=2 status=none >> $gzelfle.tmp
dd if=$gzelfle.tmp count=2 status=none > $gzelfle
rm -f $gzelfle.tmp

if file $gzelf | grep -q "gzip compressed data"; then
  cat $gzelf >> $gzelfle
else
  gzip -9c $gzelf >> $gzelfle
fi
err=$?
chmod +x $gzelfle
du -ks $gzelfle

break; done ####################################################################
test $err -eq 0

#### ///////////////////////////////////////////////////////////////////////////
