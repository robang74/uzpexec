# uzpexec

`(c)` 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, text published under CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

> [!WARNING]
>
> The [uzpexec](uzpexec.asm) (micro gzip pipe exec, written in Assembler) replaces the previous `upexec` comparison which offers as extra the integrated support for `gzip` inflate on the standard input pipe. Pre-compiled v0.68 elf32 available [here](https://github.com/robang74/working-in-progress/raw/refs/heads/main/uchaosys.qemu/uzpexec).

---

### Presentation

> [!NOTE]
>
> Suggested file extension: **`.uzp`**

Utility for executing an ELF binary directly from stdin pipe:

- it self-extracts and executes
- it adds up just 512-bytes overhead
- trivial to inflate by `dd skip=1`
- it runs gzip compressed binaries
- it runs binary via `ssh` or `wget`
- it runs in RAM only, no disk write
- it runs un/compressed scripts ([v0.74](https://github.com/robang74/gzcmd.sh/releases/tag/v0.74) or +)
- compress any script, run as ELF32

without writing it on the remote/local systems storage (by `memfd_create`).

Obviously RAM-only can be a benefit or a limit, `gzcmd.sh` writes on disk.

---

### Usage

Compiling `.asm` files requires `nasm`:

```sh
make clean tests
```

Test and then decide how to deploy.

- `{ cat uzpexec; gzip -7c $elf; }    > $elf.uzp`
- `cp uzpexec $elf.uzp; gzip -c $elf >> $elf.uzp`
- `wget $url/$elf[.gz] -O- | uzpexec [args]`
- `uzpexec <&-||echo` # for the version + github

It works as a single block 512-bytes self-inflating executable payload replacing also `gzcmd.sh` with the sole requirement of `/bin/zcat` available.

#### Example #1

An example of use is related to this [project](https://github.com/robang74/uchaosys/blob/v074/qemu/README.md) about QEMU footprint reduction which uses `uzpexec` to deliver the executable binary in `UZP` format which can be downloaded from [here](https://github.com/robang74/working-in-progress/tree/main/uchaosys.qemu)

> [!NOTE]
>
> The `qemu-system-x86_64`, provided in `UZP` self-inflate executable, appears to be an x86 ELF 32-bit LSB executable. That type file refers to the extractor. While qemu is expanded in RAM and execute in its original ELF 64-bit format.

#### Example #2

The shell script [uzpack.sh](uzpack.sh) converts a binary or a script into a self-extracting self-running in memory only. The most natural test is using the script to convert itself. Which is what happens during `make tests` and the result can be found as `uzpack.uzp`.

Obviously, it is possible to convert an already converted binary. Which fails to run when it carries a shell script, but it is acceptable because it is totally useless to convert anything twice, especially in this case.

A different result can be obtained by double converting and executing a binary (bigger is better) because it creates a fork bomb that will set the system into an OOM set down by the kernel itself... a show to enjoy with `htop` view.

---

### Script to ELF32

Activating the `do_script` mode, it converts any script into an ELF32:

```sh
bin="uzpexec"
HI() { printf '#!/bin/sh\necho Hi World!\n'| gzip -c; }
do_script() { sed -e 's,\x00\(bin/sh\),/\1,' -i $bin; }
no_script() { sed -e 's,/\(bin/sh\),\x00\1,' -i $bin; }

do_script # set the script mode
{ cat $bin; HI; }  > $bin.uzp &&
chmod +x $bin.uzp && $bin.uzp
no_script # reset back original
```

Appending a compressed script is easy and reversible without recompiling.

---

### Quick customisations

Quick customisations by `sed` and other stings-based editor is supported:

- `{ cat uzpexec | sed 's/zcat\x00/xzcat/'; xz -7c $elf; } > $elf.uxp`

Alternative to `zcat` are `xzcat` for XZ compression, or `lzcat` for LZMA.

The alternatives that are natively compatible with `-f -` are fully supported.

```asm
; ==============================================================================
; COMPACT DATA SECTION (appended to code)
; ==============================================================================
; filename can be changed by sed up to 7 chars + ending \0
; zcat -f is cat when input isn't gzip, options up to -6c\0
; /bin/zcat can be changed by sed up to 41 chars + ending \0
; - for example: /usr/local/bin/xzcat is 20 chars + ending \0
; in do_script mode the 2 paths shrink to 20 chars + ending \0
; eof_strng helps to find the EOF, and where \0 padding starts
;                                                                   LN | FD | SH
copy_vers:  db "(c) github/robang74 v0.84 "                       ; 26 | 26 | 26
filename :  db      "uzpexec", 0                                  ;  8 |  8 |  8
zcat_path:  db         "/bin/zcat",  0,0,0, 0,0,0,0, 0,0,0,0, 0   ; 21 | 21 | 21
; following fields are conditionally overwritable, do unions      : --------- 55
do_script:  db    0, "bin/sh", 0, 0, 0,0,0, 0  ; for "sh"         ; 13 | 13 | 21
force_arg:  db "-f", 0,0                       ; for "zcat"       :  4 | 12 |  -
eof_tests:  db "U238"                          ; for "make tests" :  4 |  - |  -
dash_s   :  db "-s", 0                         ; for "sh"         :  3 |  - |  3
dual_dash:  db "-"                             ; for "sh"         :  1 |  - |  1
dash_args:  db "-", 0                          ; for both         :  2 |  2 |  2
;              |<-- 8 chars -->|<- +8c ->|                        : --------- 27
                                                                  ; 82 (tot.) 82
; ==============================================================================
; PADDING: Aligned exactly to 512 bytes (dd skip=1)
; ==============================================================================
file_end:                       ; Physical end of the binary file!
times (512 - ($ - $$)) db 0     ; Padding to 512 bytes for skip=1
```

Since `zcat` is a shell script, it can be changed to pair the input with the proper decompressing tool. While a tiny `xcat` binary in ASM would be much faster in properly pairing the matches.

> [!WARNING]
>
> The following script is provided **untested** AS-IS, just for the concept:

```sh
#!/bin/sh
HEADER=$(dd bs=1 count=4 2>/dev/null)
HEX=$(printf '%s' "$HEADER" | od -An -tx1 | tr -d ' \n')
case "$HEX" in
  1f8b*)     # GZIP
      (printf '%s' "$HEADER"; cat) | gzip  -d -c "$@"
      ;;
  fd377a58)  # XZ (\xfd7zX)
      (printf '%s' "$HEADER"; cat) | xz    -d -c "$@"
      ;;
  425a68*)   # BZIP2 (BZh)
      (printf '%s' "$HEADER"; cat) | bzip2 -d -c "$@"
      ;;
  28b52ffd)  # ZSTD
      (printf '%s' "$HEADER"; cat) | zstd  -d -c "$@"
      ;;
  *)         # to support -f / --force
      (printf '%s' "$HEADER"; cat)
      ;;
esac
```

---

### Trivial facts

A 64 bit ELF would be much bigger, 2x potentially, and adding no value because this ELF32 doesn't process anything, not even the read() / write() hot loops (since the zero pipes implementation) but just a few system calls.

The `uzpexec` has been developed to compensate for the gzcmd.sh shortcomings and to add useful capability in dealing with STDIN pipe. So, the `gzcmd.sh` is this project's MVP to reach the production grade with `uzpexec`.

Every sane compressing algorithm is also self-validating in terms of output conformity with the original while executing from a url in pipe is popular but a dangerous action because man-in-the-middle attack.

When a binary is coded in Assembler and its size is something ridiculously small, then it is obvious that there is no room to deal with complications. The fork bomb explained in "Example #2" covers an aspect "*a grenade doesn't debate*", which is also the logic behind doing `SIGSEGV` instead of working around a Linux kernel bug fixed in 2022.

---

### W+X memory

Separating exectable code (X) from writing memory (W) costs bytes of code!

```txt
  dd 7                        ; p_flags (R+W+X - Read, Write, and Execute)
  dd 0x1000                   ; p_align (Standard page alignment)

  ; Security-by-Design VS Security-by-Subtraction

  ; Because uzpexec contains no input parsing logic that could be corrupted and
  ; its fixed 512-byte read loop cannot be overflowed, the writeable-executable
  ; segment offers no exploitable attack vector.

  ; Since the loader immediately forfeits control through atomic fork() / exec()
  ; or execveat() transitions that never return, an attacker cannot redirect
  ; execution to modified code before the process image is replaced.

  ; An adversary who can already write to the process memory holds sufficient
  ; privileges to inject code via ptrace or mprotect on any standard binary,
  ; which means the R+W+X flag introduces zero additional risk.

  ; WRX is the least of your troubles, but uzpexec as obscenely-powerful tool.
```

---

### Licensing terms

After all, scripts are the sources and the "running code" at the same time.

```txt
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT+1 license
;
;     MIT+1: due to the extreme nature of this software, an extra clause is
;            added to the standard MIT license, which forbids everyone to
;            remove or change the authorship string also from the binary.
;            The clause rationale is rooted in security fingerprinting and
;            due to the strong -- nearly 1:1 -- match between the Assembler
;            source code and the x86 32-bit executable code (human-machine).
;
;     The MIT+1 licensing terms apply to all the previous, current and future
;     versions, unless the author provides a public legal charter allowing a
;     designated entity to be exempted from this extra clause. Comply or delete.
;
;     Note : coded with the help of Kimi and Gemini for the size reduction,
;            this aspect deepens the link between the human and the machine.
;
;    In this specific case, MIT+1 is not a derivative of the MIT license but
;    due to the peculiar and extreme nature of this source code, the license
;    acts as a direct extension to the binary code generated by it (1sc:1bc).
```

<br>

---
---

<br>

# gzcmd.sh

A shell script that converts any ELF in a self-extracting executable for standard Unix/POSIX systems

- Initially written and committed in this repository [Bare Minimal Linux Kernel & RootFS](https://github.com/robang74/bare-minimal-linux-system) &nbsp;(2026-02-17)

The `gzcmd.sh` was the predecessor of `uzpexec` in terms of project planning and evolution. Once the `gzcmd.sh` shrunk in its payload version below 512 bytes (1 `dd` standard block), it sets the limit for developing a version in Assembler, the only other universal language that would have a chance to fit an ELF into 512 bytes.

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
