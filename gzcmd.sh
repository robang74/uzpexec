#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# Usage: gzcmd.sh /path/elf-executable[.gz] [name]
#
# Suggestion for minimal size with musl static compilation of a single file.c:
#
# musl-gcc -static -Os --fast-math -Wall -s -ffunction-sections -fdata-sections \
#   -Wl,--gc-sections -Wl,--build-id=none -fno-asynchronous-unwind-tables \
#   file.c -o uchaos; strip -R .comment -R .gnu.version uchaos
#
# Required: sudo apt install musl-tools gcc-multilib
#
################################################################################

BLKSZE=64
gzelf=${1:-gzelf}
ORIGNAME=$(basename "$gzelf")
ORIGNAME=$(echo "$ORIGNAME" | sed -e "s/\.gz$//")
MD5CKSUM=$(md5sum "$gzelf"  | cut -d' ' -f1)
gzelfle="${2:-$ORIGNAME}.gz.sh"

headstr=$(cat <<EOF
#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#           URL: raw.githubusercontent.com/robang74/bare-minimal-linux-system/
#           Source: /refs/heads/main/gzcmd.sh
#
BFN="$ORIGNAME"
MD5="$MD5CKSUM"
test -n "\$PATH" || export PATH=/bin:/usr/bin:/usr/local/bin:/\$HOME/bin
if [ !  -r "\$0" ]; then echo "ERROR: '\$0' is not readable"; exit 1; fi

for i in 1; do
  uz="pigz -dc"; which pigz >&3 && break
  uz="gzip -dc"; which gzip >&3 && break
  uz="zcat";     which zcat >&3 || exit 1
done

sm=/dev/shm; grep -qe "\$sm.*noexec" /proc/mounts && sm=
for tmp in "\${GZTMPDIR:-}" \$sm/ /tmp/ \$HOME/.tmp/; do
  mkdir -p "\$tmp" 2>&3 || continue;
  test  -d "\$tmp" -a -w "\$tmp" && break
done

dn="\$tmp/.gzcmd-\$BFN-\$MD5-\$\$"; fn="\$dn/\$BFN"
{ umask 007; mkdir -p "\$dn" && touch "\$fn"; } | 2>&3 &&
  chmod 0700 "\$dn" "\$fn" &&
     dd if=\$0 skip=BLOCKS bs=$BLKSZE status=none | \$uz >"\$fn" || exit 1

sh -c "\$fn \$@"; err=\$?; { rm -f "\$fn"; rmdir "\$dn"; } 2>&3; exit \$err
###
EOF
)
### ////////////////////////////////////////////////////////////////////////////

isgzipfile() {
  zfle=${1:-}
  file "$zfle" | grep -q "gzip compressed data" ||\
    od -h "$zfle" | head -n1 | grep -q "8b1f 0808"
}

gzdd() { dd bs=$BLKSZE count=$nblocks status=none if=$1; }

gzcmd_main_func() {

  if [ ! -n "$gzelf" ]; then
    echo "Usage: gzcmd.sh /path/elf-executable[.gz] [name]"
    return 1
  fi >&2
  if [ ! -r "$gzelf" ]; then
    echo "ERROR: executable '$gzelf' is not readable"
    return 1
  fi >&2

  headsze=$(echo "$headstr" | wc -c)
  nblocks=$(( (headsze + $BLKSZE -1) / $BLKSZE ))

  echo "$headstr" | sed "s/skip=BLOCKS/skip=$nblocks/" > "$gzelfle.tmp"
  gzdd /dev/zero >> "$gzelfle.tmp"
  gzdd "$gzelfle.tmp" > "$gzelfle"
  rm -f "$gzelfle.tmp"

  test -r "$gzelfle" || return 1
  if file "$gzelf" | grep -q "gzip compressed data"; then
    cat "$gzelf" >> "$gzelfle" || return 1
  else
    for i in 1; do
      zp="pigz"; which $zp >&3 && break
      zp="gzip"; which $zp >&3 || return 1
    done
    $zp -9c "$gzelf" >> "$gzelfle" || return 1
  fi
  err=0

  chmod +x "$gzelfle"
  str1=$(du -ks "$gzelfle" | cut -f1)
  echo "File name: '$(basename "$gzelfle")', Header size:"\
       "$headsze ($nblocks x $BLKSZE) bytes, ELF size: $str1 Kb"
  file "$gzelfle"
}

gzcmd_main_func

### ////////////////////////////////////////////////////////////////////////////
