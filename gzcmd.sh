#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# Usage: gzcmd.sh /path/elf-executable[.gz] [name]
#

gzelf=${1:-}
headstr=$(cat <<EOF
#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
# URL: raw.githubusercontent.com/robang74/bare-minimal-linux-system/
# Source: refs/heads/main/gzcmd.sh
#

test -n "\$PATH" || export PATH=/bin:/usr/bin:/usr/local/bin:/\$HOME/bin
ORIGNAME="$(basename ${1:-gzelf})"
cmdnme="\$0"
if [ ! -r "\$cmdnme" ]; then
  echo "ERROR: executable '\$cmdnme' is not readable"
  exit 1
fi >&2

uz="zcat"; if ! which \$uz >&3 ; then
  uz="gzip -dc";which gzip >&3 || exit 1
fi

sm=/dev/shm; grep -qe "\$sm.*noexec" /proc/mounts && sm=
for tmp in "\${GZTMPDIR:-}" \$sm/ /tmp/ \$HOME/.tmp/; do
  mkdir -p "\$tmp" 2>&3 || continue;
  test -d "\$tmp" -a -w "\$tmp" && break
done

datens=\$(date +%N)
flenme="\$ORIGNAME"
dirnme="\$tmp/\$flenme-\$\$-\$datens"
flenme="\$dirnme/\$flenme"
mkdir -p "\$dirnme"
chmod o-wrx "\$dirnme"

dd if=\$0 skip=BLOCKS status=none | \$uz - >"\$flenme"
chmod +x-w "\$flenme" && sh -c "\$flenme \$@"; err=\$?
{ rm -f "\$flenme"; rmdir "\$dirnme"; } 2>&3
exit \$err

###
EOF
)

err=1
while true; do #################################################################

if [ ! -n "$gzelf" ]; then
  echo "Usage: gzcmd.sh /path/elf-executable[.gz] [name]"
  break
fi >&2
if [ ! -r "$gzelf" ]; then
  echo "ERROR: executable '$gzelf' is not readable"
  break
fi >&2

headsze=$(echo "$headstr" | wc -c)
nblocks=$(( (headsze + 511) / 512 ))

gzelfle="${2:-$gzelf}.gz.sh"
echo "$headstr" | sed "s/skip=BLOCKS/skip=$nblocks/" > "$gzelfle.tmp"
dd if=/dev/zero count=$nblocks status=none >> "$gzelfle.tmp"
dd if="$gzelfle.tmp" count=$nblocks status=none > "$gzelfle"
rm -f "$gzelfle.tmp"

test -r "$gzelfle" || break
if file "$gzelf" | grep -q "gzip compressed data"; then
  cat "$gzelf" >> "$gzelfle" || break
else
  zp="pigz"; if ! which $zp >&3; then
    zp="gzip"; which $zp >&3 || break
  fi
  $zp -9c "$gzelf" >> "$gzelfle" || break
fi
err=0

chmod +x "$gzelfle"

str1=$(du -ks $gzelfle | cut -f1)
echo "File name: '$(basename $gzelfle)', Header size: $headsze bytes, ELF size: $str1 Kb"
file $gzelfle

break; done ####################################################################
test $err -eq 0

#### ///////////////////////////////////////////////////////////////////////////
