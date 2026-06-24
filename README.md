# gzcmd.sh

`(c)` 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, text published under CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

A shell script that converts any ELF in a self-extracting executable for standard Unix/POSIX systems

- Initially written and committed in this repository [Bare Minimal Linux Kernel & RootFS](https://github.com/robang74/bare-minimal-linux-system) &nbsp;(2026-02-17)

---

### Usage

Alternatively it can be used by activating the execution bit by `chmod +x gzcmd.sh` or calling it by the shell `sh gzcmd.sh`, the only parameter that matters is the ELF patch to convert and the converted file will be written in the current directory.

```sh
$ sh gzcmd.sh gzcmd.sh
FILE: 'gzcmd.gz.sh', HEAD: 502 (512), GZIP: 6780 (7 Kb, 38 %), GZSH: v0.3.1
```

#### Install

An ELF binary compressed with gzcmd.sh can be installed permanently providing a directory which resides on a writable and executable disk space:

```sh
TMPDIR=~/bin ./$filename.gz.sh    # to install in ~/bin
```

To use the converted file, launch it directly or by a shell because from the PoV of the Linux kernel is a shell script.

---

### Payload

Previous versions than **v0.1.8** had the payload size variable, which was an optimization in terms of overhead but confusing in doing an independent extraction.

Therefore the payload size had been set fixed to 1024 (two 512 blocks) because such a default value allows a trivial extraction of the gzipped appended file:

```sh
dd skip=1 if=${filename.gz.sh} | zcat - >${filename}
```

Starting from the **v0.3.1** the payload size has reduced below the 512 (1 block) size. Hence `skip=1` instead of `skip=2`. Moreover the `SZE` internal value, now it refers to the maximum memory pages (4kB) that the extracted ELF binary will take.

```sh
#!/bin/sh
# (C) 2026 robang74 l.MIT v0.3.1 git.new/ttRvFBu
BFN=hello:d713d0d05c;SZE=4
: ${PATH:=/bin:/usr/bin:/usr/local/bin}
exec 2>&-
T=".gzc-$BFN-${USER:-$(id -u)}"
for d in "${TMPDIR:-/tmp}" /run /dev/shm "${HOME:-.}/.cache"
do
F="$d/$T"
(umask 077;echo>"$F"&&chmod 700 "$F"&&"$F")&&break
rm -f "$F"
F=
done
dd if=$0 skip=1|$(command -v pigz gzip gunzip zcat|head -n1) -dc>"$F"&&{
grep -qe "tmpfs.*$d" /proc/mounts&&trap 'rm -f "$F"_' EXIT INT TERM
mv -f "$F" "$F"_&&(F=;exec "$d/$T"_ "$@")
}
exit
#1_345678
```

The padding line(s) provide(s) enough bytes to reach the fixed payload size, shortening more the payload, requires adding more padding lines, unless the size drops below 512 bytes and in that case `bs skip=1` would be enough.

#### Minimum requirements

In order to run the paylod, a few minimum requirements are need:

- **a Unix/POSIX shell**: even minimal, with basic file descriptor management.
- **shell internals**: `echo`, `exec`, `for`, `command`, `exit` and possibly `trap`
- **utilities**: `dd`, `rm`, `mv`, `head`, and possibly `grep`, `id`
- **alternatives**: `zcat` or every equivalent, `umask` or `chmod` 
- **environment**: `PATH`, and optional `HOME`, `USER`, `TMPDIR`

All of the requirements are almost always granted in every Unix/POSIX.

<br>

# uzpexec

> [!NOTE]
>
> Suggested file extension: **`.uzp`**

Utility for executing an ELF binary directly from stdin pipe:

- it runs binary via SSH/wget
- it runs gzip compressed binary
- it self-extract and execute

without writing it on the remote/local systems (memfd_create).

```sh
make clean tests
```

The [uzpexec](uzpexec.asm) (micro gzip pipe exec) replaces the previous `upexec` compared which it offers as extra the integrate support for `gzip` inflate on the standard input pipe.

```text
; USAGE:
; - a)  { cat uzpexec; gzip -7c $elf; }    > $elf.uzp
; - b)  cp uzpexec $elf.uzp; gzip -c $elf >> $elf.uzp
; - c)  wget $url/$elf[.gz] -O- | uzpexec [args]
```

It works as single block 512-bytes self-inflating executable payload replacing also `gzcmd.sh` with the sole requirement of `/bin/zcat` available.
