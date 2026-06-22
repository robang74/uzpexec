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
FILE: 'gzcmd.gz.sh', HEAD: 863 (1024), GZIP: 7439 (7 Kb, 42 %), GZSH: v0.2.0
```

To use the converted file, launch it directly or by a shell because from the PoV of the Linux kernel is a shell script.

---

### Payload

The payload size is always 1024 (two 512 blocks) because such a default value allows a trivial extraction of the gzipped appended file:

```sh
dd skip=2 if=${filename.gz.sh} | zcat - >${filename}
```

#### Customisations

The payload is specific for every converted file but potentially can be generalised removing the following line:

```sh
MD5="$MD5CKSUM";BFN="$ORIGNAME";SZE="$((ORIGSIZE>>10))k"    # to remove
```

and for a more shorter version replacing the following line with a graph `{` parentesys:

```sh
$GZCSUMCK "\$_fn"|grep -qe "^\$MD5"||{    # to replace with {
```

It will be shorter and faster to execute but every time it will extract the ELF, therefore losing the install:

```sh
GZCTMP=~/bin ./$filename.gz.sh    # to install in ~/bin
```

The three padding lines provide `20 x 80 = 240` bytes to reach the 1024 fix size, shortening more the payload, requires adding more padding lines, unless the size drops below 512 bytes and in that case `bs skip=1` would be enough.

On a fully controlled system the payload can be as shorter as the code used for extracting the gzipped load.

<br>

# upexec

```sh
Usage: zcat elf.gz | upexec [args]
```

### Rationale upexec (micro pipe exec)

Utility for executing an ELF binary directly from stdin pipe:

- it runs binary via SSH/wget
- it runs compressed binary

without writing it on the remote/local systems (memfd_create).

```sh
# Compile and test (simple example)

cc -Os -s hello.c -o hi && du -b hi && gzip -f hi && du -b hi.gz
# 14472 hi
#  1868 hi.gz

nasm -O2 -f bin upexec.asm -o upexec && du -b upexec && chmod a+x upexec
#   242 upexec

export WORLD=beatyful; zcat hi.gz | ./upexec $WORLD; echo $?
# Hello beautiful World!
#   HOME:  /home/roberto
#   WORLD: beautiful
# 0

file upexec
# upexec: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV),
# statically linked, no section header
```

or even simpler:

```sh
make clean tests
```

