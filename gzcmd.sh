#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# Version : v0.1.2
# Usage   : gzcmd.sh /path/elf-executable[.gz] [filename] [blocksize]
# Hint    : for blocksize use $(cat filename |wc -c) for minimal size
# Host    : [[export] GZTMPDIR=path GZUNGZIP=pigz;] [shell] elf.gz.sh
#
# Suggestion for minimal size with musl static compilation of a single file.c:
#
# musl-gcc -static -Os --fast-math -Wall -s -ffunction-sections -fdata-sections \
#   -Wl,--gc-sections -Wl,--build-id=none -fno-asynchronous-unwind-tables \
#   file.c -o uchaos; strip -R .comment -R .gnu.version uchaos
#
# Requires: sudo apt install musl-tools gcc-multilib
#
################################################################################
#
# Rationale
#
# Both UPX and APE are powerful but troublesome, in some cases also
# over-complicating for Linux users. A shell wrap (thus pays a shell
# time start) is a standard way that can works in all cases. In some
# cases is easier and even a better way to go, in some others is less
# competitive. The shell spawn time may vary (bash vs built-in toysh).
#
# Testing gzcmd.sh vs upx-cli, not that memory footprint can widely varying
# in particular when /dev/shm is used rather than a on-disk temporary path.
#
################################################################################
if [ "x${1:-}" = "x--do-tests" ]; then #########################################

gzpath=${gzpath:-"$HOME/robang74/bare-minimal-linux-system"}

dotest() {
  str=$({ { time cat dmesg.txt | $@ | wc -c; } 2>&1 |\
    grep -E "512|real"; du -b ${2:-$1}; } | tr '\n\t' ' ';)
  echo $str $(echo $str | grep -qe "^512" && printf "ok" || printf "KO") |\
    sed "s/^512 /   512 /"
}

domusl() {
  musl-gcc -static -O3 --fast-math -Wall -s -ffunction-sections -fdata-sections \
    -Wl,--gc-sections -Wl,--build-id=none -fno-asynchronous-unwind-tables \
      uchaos.c -o uchaos.musl && strip -R .comment -R .gnu.version uchaos.musl &&
          mv -f uchaos.musl uchaos.musl.orig
}

rm -f ./uchaos.orig

gcc uchaos.c -O3 -s --fast-math -Wall -o uchaos.orig
dotest ./uchaos.orig
dotest ./uchaos.orig "" -qT 1000

cp -f uchaos.orig uchaos.upx
upx --ultra-brute uchaos.upx >&3
dotest ./uchaos.upx
dotest ./uchaos.upx "" -qT 1000

sh $gzpath/gzcmd.sh uchaos.orig uchaos >&3
dotest sh ./uchaos.gz.sh
dotest sh ./uchaos.gz.sh
dotest sh ./uchaos.gz.sh "" -qT 1000

#    512 real 0m0.013s 18584 ./uchaos.orig  ok
# 512000 real 0m0.148s 18584 ./uchaos.orig  ok
#    512 real 0m0.014s  9984 ./uchaos.upx   ok
# 512000 real 0m0.146s  9984 ./uchaos.upx   ok
#    512 real 0m0.018s  8302 ./uchaos.gz.sh ok
# 512000 real 0m0.155s  8302 ./uchaos.gz.sh ok (+7 ms, -1682 bytes)

rm -f ./uchaos.static

gcc uchaos.c -O3 -s --fast-math -Wall -o uchaos.static -static
dotest ./uchaos.static
dotest ./uchaos.static "" -qT 1000

cp -f uchaos.static uchaos.upx
upx --ultra-brute uchaos.upx >&3
dotest ./uchaos.upx
dotest ./uchaos.upx "" -qT 1000

cp -f uchaos.static uchaos.upx
upx uchaos.upx >&3
dotest ./uchaos.upx
dotest ./uchaos.upx "" -qT 1000

sh $gzpath/gzcmd.sh uchaos.static uchaos >&3
dotest sh ./uchaos.gz.sh
dotest sh ./uchaos.gz.sh "" -qT 1000

#    512 real 0m0.013s 836080 ./uchaos.static ok
# 512000 real 0m0.149s 836080 ./uchaos.static ok
#        real 0m0.013s 278792 ./uchaos.upx    KO <-- FAIL!!
#        real 0m0.014s 278792 ./uchaos.upx    KO <-- FAIL!!
#    512 real 0m0.016s 334524 ./uchaos.upx    ok
# 512000 real 0m0.154s 334524 ./uchaos.upx    ok
#    512 real 0m0.019s 350020 ./uchaos.gz.sh  ok
# 512000 real 0m0.156s 350020 ./uchaos.gz.sh  ok (+2 ms, +15496)

rm -f ./uchaos.musl.orig

domusl
dotest ./uchaos.musl.orig
dotest ./uchaos.musl.orig "" -qT 1000

cp -f uchaos.musl.orig uchaos.musl
upx --ultra-brute uchaos.musl >&3
dotest ./uchaos.musl
dotest ./uchaos.musl "" -qT 1000

cp -f uchaos.musl.orig uchaos.musl
sh $gzpath/gzcmd.sh uchaos.musl >&3
dotest sh ./uchaos.musl.gz.sh
dotest sh ./uchaos.musl.gz.sh "" -qT 1000

#    512 real 0m0.013s 50504 ./uchaos.musl.orig  ok
# 512000 real 0m0.149s 50504 ./uchaos.musl.orig  ok
#    512 real 0m0.013s 26376 ./uchaos.musl       ok
# 512000 real 0m0.146s 26376 ./uchaos.musl       ok
#    512 real 0m0.022s 24912 ./uchaos.musl.gz.sh ok
# 512000 real 0m0.163s 24912 ./uchaos.musl.gz.sh ok (+14 ms, -1464 bytes)

exit; fi #######################################################################
################################################################################

gzelf=${1:-gzelf}
ORIGNAME=$(basename "${2:-$gzelf}")
ORIGNAME=$(echo "$ORIGNAME" | sed -e "s/\.gz$//")
MD5CKSUM=$(md5sum "$gzelf"  | cut -d' ' -f1)
gzelfle="$ORIGNAME.gz.sh"
BLKSIZE=${3:-32}

headstr=$(cat <<EOF
#!/bin/sh
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#           URL: raw.githubusercontent.com/robang74/bare-minimal-linux-system/
#           Source: /refs/heads/main/gzcmd.sh
#
BFN="$ORIGNAME"
MD5="$MD5CKSUM"
test -n "\$UID"  || UID=$(id -u 2>&3)
test -n "\$PATH" || export UID PATH=/bin:/usr/bin:/usr/local/bin
if [ !  -r "\$0" ]; then echo "ERROR: '\$0' is not readable"; exit 1; fi
gpm() { grep -qe '\$@' /proc/mounts; }

sm=/dev/shm; gpm "\$sm.*noexec" && sm=
for tmp in "\${GZTMPDIR:-}" \$sm /tmp \$HOME/.tmp; do
  mkdir -p "\$tmp/" 2>&3 || continue
  test  -d "\$tmp/" -a -w "\$tmp/" && break
done

dn="\$tmp/.gzcmd-\$BFN-\$MD5-\$UID"; fn="\$dn/\$BFN"
if ! md5sum \$fn 2>&3 | grep -qe "^\$MD5 "; then
  for i in \${GZUNGZIP:-} pigz gzip zcat; do
    uz=\$i; which \$uz >&3 && break
  done
  { umask 007; mkdir -p "\$dn" && touch "\$fn"; } | 2>&3 &&
    chmod 0700 "\$dn" "\$fn" &&
       dd if=\$0 skip=BLOCKS bs=$BLKSIZE status=none | \$uz -dc >"\$fn" || exit 1
fi

eval sh -c "'\$fn \$@'"; err=\$?;
gpm "tmpfs.*/dev/shm" && { rm -f "\$fn"; rmdir "\$dn"; } 2>&3;
exit \$err
###
EOF
)
### ////////////////////////////////////////////////////////////////////////////

isgzipfile() {
  zfle=${1:-}
  file "$zfle" | grep -q "gzip compressed data" ||\
    od -h "$zfle" | head -n1 | grep -q "8b1f 0808"
}

gzdd() { dd bs=$BLKSIZE count=$nblocks status=none if=$1; }

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
  nblocks=$(( (headsze + $BLKSIZE -1) / $BLKSIZE ))

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
       "$headsze ($nblocks x $BLKSIZE) bytes, ELF size: $str1 Kb"
  file "$gzelfle"
}
gzcmd_main_func

### ////////////////////////////////////////////////////////////////////////////
