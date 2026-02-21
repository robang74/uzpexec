#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
# Usage   : gzcmd.sh /path/elf-executable[.gz] [filename] [blocksize]
# Hint    : set blocksize as headersize +2 from gzcmd.sh for min.size
# Host    : [[export] GZTMPDIR=path GZUNGZIP=pigz;] [shell] elf.gz.sh
# Install : sudo sh -c "[export] GZTMPDIR=/usr/local/bin; elf.gz.sh"
  RVERSION="v0.1.5"
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
# Both UPX and APE are powerful but troublesome [¹], in some cases also
# over-complicating for Linux users. A shell wrap (thus pays a shell
# time start) is a standard way that can works in all cases. In some
# cases is easier and even a better way to go, in some others is less
# competitive. The shell spawn time may vary (bash vs built-in toysh).
#
# Testing gzcmd.sh vs upx-cli, note that memory footprint can widely varying
# in particular when /dev/shm is used rather than a on-disk temporary path.
# Howver, the best aspect of gzcmd.sh is being totally agnostic about the
# executable to compress, including scripts on which UPX fails, obviously.
#
# Feedback from UPX: github.com/upx/upx/issues/911#issuecomment-3922221407
#
# Using a storage temporary path instead of a memory one, increases a bit
# the 1st call but speed-up all the others, especially for large archives.
# By extension, root can use it for a temporary or permanent installation.
# Instead the remote installation wget $url -O- | sh is still missing by $0.
#
# Finally, in embedded systems w/busybox once configured properly the enviroment
# the .gz.sh binaries shows a starting time that can differ not more than 10 ms
# and the overall performances strongly improves in calls after the first one.
#
# Notes
#
# ¹: for example cross-compiled binaries aren't simply managed outside the
#    specific tool-chain / dev-enviroment. file uchaos: ELF 32-bit LSB pie
#    executable, Intel 80386, version 1 (SYSV), static-pie linked, stripped
#    with upx-cli running on a x86_64 GNU/Linux reports a failure: 
#
# upx: CantPackException: bad DT_GNU_HASH n_bucket=0x1 n_bitmask=0x1 len=0x18
#
#    In this specific case the UPX easiest option is to abbandond static musl
#    and go with static libc, but the confrontation between the two is clear:
#
#  24293  uchaos-v0.23-linux-x86-32-static-musl.gz.sh
# 304700  uchaos-v0.23-linux-x86-64-ld-3.20-elf32.upx (a bit smaller than -11)
#
#    Which is a gret result for UPX that create a compressed self-contained ELF
#    a bit smaller than pigz -11 can do but 12.5x bigger than musl whatever the
#    solution exists, it is an extra bruden which aligns with the the UI/UX for
#    Posix users that are bothered about chmod +x and the executable bits are
#    somthing that is good-practice to disable in dev enviroment and githup prj.
#
#    In conclusion, UPX can be great for Windows users or those needs to cope w/
#    that platform but on Posix where the system helps devs, then UPX seems an
#    overcomplicaiton over well-established dev-friendly universal-standards.
#    Unsurprisingly, over-complicating requires over-engineering, at least. 
#
################################################################################
if [ "x${1:-}" = "x--do-tests" ]; then #########################################

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

url="raw.githubusercontent.com/robang74/bare-minimal-linux-system"
ref="refs/heads/main/gzcmd.sh"

wget $url/$ref -qO gzcmd.sh.orig
{ time sh gzcmd.sh.orig gzcmd.sh.orig gzcmd 33; } 2>&1 | grep real
cp -f gzcmd.sh.orig gzcmd.sh.upx; chmod +x gzcmd.sh.upx
upx --ultra-brute gzcmd.sh.upx >&3; du -b gzcmd*
{ time ./gzcmd.gz.sh  gzcmd.sh.orig gzcmd 33;   } 2>&1 | grep real

# File name: 'gzcmd.gz.sh', Header size: 1089 (33 x 33) bytes, ELF size: 4 Kb
# gzcmd.gz.sh: POSIX shell script executable (binary data)
# real	0m0.027s
# 3634	gzcmd.gz.sh       (upx -1025 bytes)
# 7211	gzcmd.sh.orig
# 4669	gzcmd.sh.upx      <-- FAIL TO RUN!!
# real	0m0.036s          (+9 ms, -50% bytes)

rm -f ./gzcmd.elf gzcmd.static

CFLAGS="-O3 " shc -f gzcmd.sh.orig -o gzcmd.elf
CFLAGS="-O3 -static" shc -f gzcmd.sh.orig -o gzcmd.static
CC="musl-gcc" CFLAGS="-O3 -static -s" shc -f gzcmd.sh.orig -o gzcmd.musl
{ dotest ./gzcmd.static; dotest ./gzcmd.elf; } | sed -e "s/KO$//"

# real 0m0.023s 968368 ./gzcmd.static
# real 0m0.020s  27352 ./gzcmd.elf

dotest ./gzcmd.gz.sh
 du -b ./gzcmd.gz.sh
for i in elf static musl; do
  cp -f gzcmd.$i gzcmd.$i.upx
   ./gzcmd.gz.sh gzcmd.$i >&3
  upx --ultra-brute gzcmd.$i.upx >&3
  dotest ./gzcmd.$i.gz.sh
  dotest ./gzcmd.$i.upx
   du -b ./gzcmd.$i
done | sed -e "s/KO$//"

# real 0m0.026s   3634 ./gzcmd.gz.sh        <-- Great but not obscure/proprietary
#                 3634 ./gzcmd.gz.sh
# real 0m0.027s  16218 ./gzcmd.elf.gz.sh    <-- Obscurated (+7 ms, -1854 bytes)
# real 0m0.020s  18072 ./gzcmd.elf.upx
#                27120 ./gzcmd.elf
# real 0m0.028s 402516 ./gzcmd.static.gz.sh
# real 0m0.013s 318756 ./gzcmd.static.upx   <-- Faster but 88x bigger
#               967440 ./gzcmd.static
# real 0m0.033s  43392 ./gzcmd.musl.gz.sh   <-- Slower (+19 ms, -164 bytes)
# real 0m0.014s  43556 ./gzcmd.musl.upx     <-- Faster but 12x bigger
#                72192 ./gzcmd.musl

rm -f ./uchaos.orig

gcc uchaos.c -O3 -s --fast-math -Wall -o uchaos.orig
dotest ./uchaos.orig
dotest ./uchaos.orig "" -qT 1000

cp -f uchaos.orig uchaos.upx
upx --ultra-brute uchaos.upx >&3
dotest ./uchaos.upx
dotest ./uchaos.upx "" -qT 1000

./gzcmd.gz.sh uchaos.orig uchaos >&3
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

./gzcmd.gz.sh uchaos.static uchaos >&3
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
./gzcmd.gz.sh uchaos.musl >&3
dotest sh ./uchaos.musl.gz.sh
dotest sh ./uchaos.musl.gz.sh "" -qT 1000

#    512 real 0m0.013s 50504 ./uchaos.musl.orig  ok
# 512000 real 0m0.149s 50504 ./uchaos.musl.orig  ok
#    512 real 0m0.013s 26376 ./uchaos.musl       ok
# 512000 real 0m0.146s 26376 ./uchaos.musl       ok
#    512 real 0m0.022s 24912 ./uchaos.musl.gz.sh ok
# 512000 real 0m0.163s 24912 ./uchaos.musl.gz.sh ok (+14 ms, -1464 bytes)

################################################################################
if false; then # Testing with Busybox in QEMU bare minimal Linux system ########

mount

# none on /     type rootfs   (rw)
# none on /proc type proc     (rw,relatime)
# none on /sys  type sysfs    (rw,relatime)
# none on /dev  type devtmpfs (rw,relatime)

echo | time -v uchaos.gz.sh | wc -c

# Command being timed: "uchaos.gz.sh"
#	User time (seconds): 0.01
#	System time (seconds): 0.00
#	Percent of CPU this job got: 95%
#	Elapsed (wall clock) time (h:mm:ss or m:ss): 0m 0.02s
#	Maximum resident set size (kbytes): 7792
#	Minor (reclaiming a frame) page faults: 1272
#	Voluntary context switches: 39
#	Involuntary context switches: 6
#	Page size (bytes): 4096

echo | time -v uchaos.upx | wc -c

# Command being timed: "uchaos.upx"
# User time (seconds): 0.00
# System time (seconds): 0.00
# Percent of CPU this job got: 100%
# Elapsed (wall clock) time (h:mm:ss or m:ss): 0m 0.00s
# Maximum resident set size (kbytes): 6560
# Minor (reclaiming a frame) page faults: 27
# Voluntary context switches: 1
# Involuntary context switches: 2
# Page size (bytes): 4096

mkdir -p /tmp # This settings allows to optimize the 2nd+ starting time

echo | GZTMPDIR=/tmp GZUNGZIP=zcat time -v uchaos.gz.sh | wc -c

# Command being timed: "uchaos.gz.sh"
# User time (seconds): 0.00
# System time (seconds): 0.00
# Percent of CPU this job got: 66%
# Elapsed (wall clock) time (h:mm:ss or m:ss): 0m 0.00s
# Maximum resident set size (kbytes): 7536
# Minor (reclaiming a frame) page faults: 1055
# Voluntary context switches: 36
# Involuntary context switches: 7
# Page size (bytes): 4096

echo | GZTMPDIR=/tmp GZUNGZIP=zcat time -v uchaos.gz.sh | wc -c

# Command being timed: "uchaos.gz.sh"
# User time (seconds): 0.00
# System time (seconds): 0.00
# Percent of CPU this job got: 90%
# Elapsed (wall clock) time (h:mm:ss or m:ss): 0m 0.01s
# Maximum resident set size (kbytes): 7520
# Minor (reclaiming a frame) page faults: 566
# Voluntary context switches: 17
# Page size (bytes): 4096

################ Testing with Toybox in QEMU bare minimal Linux system #########

mount

# none on / type rootfs (rw)
# dev on /dev type devtmpfs (rw,relatime)
# dev/pts on /dev/pts type devpts (rw,relatime,mode=600,ptmxmode=000)
# proc on /proc type proc (rw,relatime)
# sys on /sys type sysfs (rw,relatime)

toybox --version

# toybox 0.8.13

echo | time -v uchaos.upx >/dev/null

# Real time (s): 0.005478
# User time (s): 0.000000
# System time (s): 0.005036
# Max RSS (KiB): 608
# Minor faults: 26
# Voluntary context switches: 1
# Involuntary context switches: 1

echo | GZTMPDIR=/tmp GZUNGZIP=/bin/zcat time -v uchaos.gz.sh >/dev/null

# Real time (s): 0.021723
# User time (s): 0.011403
# System time (s): 0.007242
# Max RSS (KiB): 700
# Minor faults: 539
# Voluntary context switches: 33
# Involuntary context switches: 3

echo | GZTMPDIR=/tmp GZUNGZIP=/bin/zcat time -v uchaos.gz.sh >/dev/null

# Real time (s): 0.008651
# User time (s): 0.007660
# System time (s): 0.000000
# Max RSS (KiB): 676
# Minor faults: 220
# Voluntary context switches: 11
# Involuntary context switches: 3

fi #############################################################################
exit; fi # x--do-tests #########################################################
################################################################################

gzelf=${1:-gzelf}
ORIGNAME=$(basename "${2:-$gzelf}")
ORIGNAME=$(echo "$ORIGNAME" | sed -e "s/\.gz$//" -e "s/\.sh$//")
MD5CKSUM=$(md5sum "$gzelf"  | cut -d' ' -f1)
ORIGSIZE=$(du -b "$gzelf"   | cut -f1)
gzelfle="$ORIGNAME.gz.sh"
BLKSIZE=${3:-32}
ZCMPLVL=${4:-9}
EXITSTR="exit \$? ####"
# md5sum check after gunzip was for debug only, a corrupted archive fails anyway.
headstr=$(cat <<EOF
#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#      URL: raw.githubusercontent.com/robang74/bare-minimal-linux-system/
#      SRC: /refs/heads/main/gzcmd.sh, VER: $RVERSION
####
MD5="$MD5CKSUM"
BFN="$ORIGNAME"
SZE="$ORIGSIZE"

test "\${GZDEBUG:-0}" -eq 0 && exec 3>/dev/null || { set -x; exec 3>&2; }
test -r "\$0" || { echo "ERROR: '\$0' is not readable" >&2; exit 1; }
test -n "\$PATH" || export PATH=/bin:/usr/bin:/usr/local/bin

mdc() { [ -r "\$fn" ] && { md5sum "\$fn" | grep -qe "^\$MD5 "; }; }
gpm() { grep -qe "\$@" /proc/mounts 2>&3; }

drn=\$(cd /var/run && pwd -P) 2>&3
for d in "\${GZTMPDIR:-/run}" /dev/shm /tmp \$drn \$HOME/.tmp; do
  gpm " \$d .*noexec" || mkdir -p "\$d/" 2>&3 &&
  test  -d "\$d/" -a -w "\$d/" && break
done; echo "DBG> tmp: \$d \$PPID \$\$" >&3

dn="\$d/.gzcmd-\$BFN-\$(printf "%.6s" \$MD5)-\$(id -u || echo 1000)"
fn="\$dn/\$BFN"; echo "DBG> fn: \$fn" >&3;
if mdc; then exec "\$fn" "\$@"; else
  for i in \${GZUNGZIP:-} pigz gzip zcat; do
    uz=\$i; which \$uz >&3 && break
  done
  wn="\$fn.\$(date +%N)"; gpm "tmpfs.*\$d" &&
    trap 'rm -f "\$wn" "\$fn"; rmdir "\$dn" 2>&3' EXIT INT TERM
  ( umask 007 2>&3; mkdir -p "\$dn" && touch "\$wn" && chmod -R 0700 "\$dn" ) &&
    dd if=\$0 skip=1 bs=SIZE status=none | \$uz -dc >"\$wn" &&
      mv -f "\$wn" "\$fn" || exit 1
  "\$fn" "\$@"
fi; $EXITSTR
___
EOF
)
### ////////////////////////////////////////////////////////////////////////////

isgzipfile() { od -h ${1:-} | head -n1 | grep -q "8b1f 0808"; }

md5c() { gzdd skip=1 count=1G if="$1" | $zp -dc | md5sum | -qe "^$MD5CKSUM "; }
gzdd() { dd count=1 bs=$headsze status=none "$@"; }
phdr() { echo "$headstr"; }

gzcmd_main_func() {
  exec 3>/dev/null

  if [ ! -n "$gzelf" ]; then
    echo "Usage: gzcmd.sh /path/elf-executable[.gz] [name]"
    return 1
  fi >&2
  if [ ! -r "$gzelf" ]; then
    echo "ERROR: executable '$gzelf' is not readable"
    return 1
  fi >&2

  # select the best-first binary for gzip compression
  for i in 1; do
    zp="pigz"; which $zp >&3 && break
    zp="gzip"; which $zp >&3 || return 1
  done

  # top-half script is 64-bit chunked in size, always
  headsze=$(( ( ($(phdr | wc -c) + 7 ) >> 3 ) << 3 ))
  # replacing the string HDRSIZE with a 4 digits number
  hdrtext=$(phdr | sed -e "s/1 bs=SIZE/1 bs=$headsze/")

  # create a monotonic enumered temporary file ext.
  atm=$(date +"%N"); wrkfle="$gzelfle.$atm"
  # setting privileges on target file before writing it
  ( rm -f "$wrkfle"; umask 0600 | touch "$wrkfle"; chmod 0600 "$wrkfle" )
  # initialising the target file with a the top-half
  echo "$hdrtext" | gzdd > "$wrkfle" || return 1
  
  # self-compressing therefore leave behind the testing stuff
  # to include everything gzip first then gzcmd over the .gz
  nme=$(basename $0); xdo="x--do";
  zip="$zp -${ZCMPLVL}c"; zpc="$zip \"$gzelf\""
  if [ "$ORIGNAME" = "$nme" -o  "$ORIGNAME.sh" = "$nme" ]; then
    nhd=$(grep -ne " = \"$xdo-tests" "$gzelf" | cut -d: -f1)
    ntl=$(grep -ne "fi # $xdo-tests" "$gzelf" | cut -d: -f1)
    if [ -n "$nhd" -a -n "$ntl" ]; then
      txt1=$(head -n$((nhd-2)) "$gzelf")
      txt2=$(tail -n-$(($(cat "$gzelf" | wc -l)-ntl)) "$gzelf")
      zpc="printf \"%s\\n%s\\n\" \"\$txt1\" \"\$txt2\" | $zip"
    fi
  elif isgzipfile "$gzelf" ; then
    zpc="$zp -dc \"$gzelf\" | $zip"
  fi
  # finalise the target file + an extra check about proper file creation
  if ! eval "$zpc" | gzdd seek=1 count=1G of="$wrkfle" && md5c "$wrkfle"; then
    echo "ERROR: gzdata isn't where supposed to, report the bug" >&2
    echo "       sh -x <same command given> 2>&1 | grep -e '^+'" >&2
    return 1
  fi
  # atomic substitution
  if ! mv -f "$wrkfle" "$gzelfle"; then
    # remove also the target
    rm -f "$wrkfle" "$gzelfle"
    return 1
  fi

  # prepare and display a summary report
  szeb=$(du -b "$gzelfle" | cut -f1)
  szek=$(( ( szeb + 512 ) >> 10 ))
  rtio=$(( ((100 * szeb) + (ORIGSIZE >> 2)) / ORIGSIZE ));
  nhsh=$(sed -ne "/$EXITSTR/p" "$gzelfle" | tr -dc '#' | wc -c)
  printf "FILE: '%s', HEAD: %d (%d), GZIP: %d (%d Kb, %d %%)%s, GZSH: $RVERSION\n" \
    $(basename "$gzelfle") $headsze $nhsh $szeb $szek $rtio \
      "${ntl:+, SKIP: $nhd:$ntl}"
  # standard permissions + user-only execution
  chmod 0744 "$gzelfle"
}
gzcmd_main_func

### ////////////////////////////////////////////////////////////////////////////
