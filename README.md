# uzpexec

`(c)` 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, text published under CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

---

A 512-byte polymorphic stub/payload ([uzpexec](uzpexec.asm)) written in Assembler that converts ELF and scripts into executable gzip packages (UZP). It runs in RAM also when started by the STDIN pipe, ssh or wget, and the carryload is trivial to extract by `dd skip=1`.

- Pre-compiled `ELF32` (for all x86 arch) available in [releases](https://github.com/robang74/uzpexec/releases/).
- Development happens in [devel](https://github.com/robang74/uzpexec/tree/devel) branch, testing on [devsrc](https://github.com/robang74/uzpexec/releases/tag/devsrc) tag.

> [!NOTE]
> 
> Only the stub, which executes the compressed binary or script, runs as ELF32 and it makes perfect sense since its role is to deal with few system calls and runs everywhere (x86 all arches, because the Assembler is a machine specific language). Obviously the ELF32 nature of the launcher doesn't affect in any manner what is executed which runs by its own kind (cfr. examples).

> [!WARNING]
> 
> Since the release **v0.93** packages contain [uzpexec.arm](uzpexec.arm) source file for **ARM64** versioned as v0.33. That source compiles but it is still experimental and reasonably affected by bugs because for a full validation it is a required a complete aarch64 system. However, testing with `qemu-aarch64-static` 10.2.3 in its original and customised form helped a lot to improve the x86 version.

---

<br>

### INDEX

- [Release](#release) ‒ [Usage](#usage) ‒ [License](#license)
- [Presentation](#presentation) ‒ [Deploying](#notes-for-deploying) ‒ [Compile](#how-to-compile) ‒ [Python](#python-support) ‒ [BusyBox](#busybox-support)
- [Examples](#example-1) ‒ [Customisation](#quick-customisation) ‒ [Trivials](#trivial-facts) ‒ [TeenyELF](#wrx-memory) ‒ [gzcmd.sh](#gzcmdsh)

<br>

### RELEASE

Current [release](https://github.com/robang74/uzpexec/releases/) is **v0.98.2** on the `master` branch.

- This release v0.98, moves forward integrating the `zstd` support and being self-sufficient in executing from `STDIN` plain inputs, and it is freed from `zcat -f` potentially insecure option.

- In v0.98 the `sed` customisation returns fully available for running a `uzpexec` self-extracting binary on a system&thinsp;/&thinsp;container with `/usr/local` from a `make install` installation.

- In v0.98.1, the `gzip`&thinsp;/&thinsp;`pigz` format returns as default because it is universally available. In v0.98.2, the BusyBox `u|zcat` seamless inflating `zstd` file-only limitation has been worked-around.

- `ff6cf62 - 2026-08-02 - README.md: compression data in table was completely wrong, fixed`

<br>

### USAGE

The use of `uzpexec` extends every GitHub action from executing whatever is installable by their internal repository to whatever is available by an URL access. Despite this potential, running `uzpexec` directly isn't probably your goal as end-user, but `uzpack` to create compressed self-extracting in RAM executables:

```sh
Usage: uzpack [-h|--help] [-v|--version]
       uzpack origin [destination[.uzp]]
       uzpack [-x: debug | -1/-19: pigz]
 export UZCMD=[zstd | (any other ztool)]
```

This tool comes with its `man` page [uzpack.1](uzpack.1) which can be read by GitHub via [uzpack.md](uzpack.md). However, the help from the script is pretty clear, and its development is simplicity-oriented.

```sh
sh ./uzpack.sh uzpack.sh uzpack
./uzpack -v
```

Moreover, the shell script `uzpack.sh` is able to convert itself into a standalone executable converter by incorporating itself via `base64` binary-to-text conversion. Via shebang and Linux kernel `binfmt_script` standard registration, script support is extended to any interpreter installed on the system, in particular python.

### Requirements

- `/bin/sh`, `/bin/zcat` (gunzip), `/proc` mounted, Linux kernel 3.19 or later.

- `/bin/zstd` for creation, and `/bin/zstdcat` for 1GB/s in memory extraction.

- `/bin/base64` for stand-alone conversion and `python` in PATH for `.py` scripts.

<br>

### LICENSE

**In short**: MIT the source and MIT the binary, because compiling the source we get
the executable, and by disassembling the binary we get the source (var names apart)
due its extreme nature and Assembler coding. Hence, the MIT terms apply to both.

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
;  The MIT+1 licensing terms apply to all the previous, current and future
;  versions, unless the author provides a public legal charter allowing a
;  designated entity to be exempted from this extra clause. Comply or delete.
;
;      Note: coded with the help of Kimi and Gemini for the size reduction,
;            this aspect deepens the link between the human and the machine.
;
;  In this specific case, MIT+1 is not a derivative of the MIT license but
;  due to the peculiar and extreme nature of this source code, the license
;  acts as a direct extension to the binary code generated by it (1sc:1bc).
```

After all, scripts are the sources and the "running code" at the same time.

<br><hr><br>

### PRESENTATION

The `uzpexec` is an utility for executing a compressed `ELF` binary or a script from `STDIN` or alternatively from a carryload appended to it, and the two are independent and complementary ways of working.

- it extracts and executes
- it adds a **just 512-bytes** stub
- trivial to inflate by `dd skip=1`
- it runs binary via `ssh` or `wget`
- it runs in **RAM only**, no disk write
- it converts **ELF and shell scripts**, both
- it works with `dash`, `bash`, and busybox `ash`
- it executes from `STDIN` by internal `read`/`write`
- qemu-friendly `execveat()` bug fallback to `execve()`
- reserved `provider` field for customisations

Using `uzpexec` to convert `uzpack.sh` generates a tool that can convert executables.

Soon after `uzpack.sh` incorporates `uzpexec` as payload, it can work in standalone mode.

In a standalone mode, it can convert itself in `uzpack` and it becomes self-hosted, also.

- `stub + script --> script w/ payload --> self-hosted ELF32 executable converter tool`

It supports natively the `gzip` (legacy) and `zstd` (fastest) carryload formats extraction.

#### Features log

- Support extentions: from `dash`-only to every shell in v0.92, [python](#python-support) scripts since v0.95, `zutils` + `binfmt_script` since v0.97, `zstdcat` internal support since v0.98.

- Since v0.96, it aims to keep the `uzpexec` uncustomised as much as possible and, instead, relies on system standards like `binfmt_script`, zutils `zcat` and busybox `zcat` with seamless decompression, and offering [`uzcat`](uzcat.asm) as a lightweight alternatives for system customisation.

- RAM-only, without writing on the remote&thinsp;/&thinsp;local systems storage because `memfd_create()`. Obviously when RAM-only is a benefit otherwise [gzcmd.sh](#gzcmdsh) writes on disk&thinsp;/&thinsp;tmpfs.

#### For providers

- Customisations are [allowed](#quick-customisation) strictly within the [licensing](#licensing-terms) terms and the dedicated 8-char field for the provider identifier&thinsp;/&thinsp;nickname.

- Providers who will disclose their changes with the author will (on their request) be listed here with their chosen identifier&thinsp;/&thinsp;nickname.

#### Trustability

- defender notes: already in README.md
- signed sha256sum releases: by GitHub
- reproducible builds: by design / ASM
- custom distribution: provider field

---

### Notes for deploying

#### 0. use the source

- Unless a binary pre-compiled package is needed, download the source [`.zip`](https://github.com/robang74/uzpexec/archive/refs/heads/master.zip) archive from github `master` branch.

#### 1. deploy responsibly

- Those who are planning to deploy&thinsp;/&thinsp;distribute self-extracting binaries, may consider to recompile `uzpexec` as loader with `make JE_STDIN=_NO_STDIN` to avoid users extract it with `dd count=1` for lazy&thinsp;/&thinsp;unsafe pipeline executions.

- Instead, embedded system architects&thinsp;/&thinsp;engineers are going to appreciate this feature in `uzpexec` as command-line tool because they have a stricter control about users&thinsp;/&thinsp;accesses, thus over the pipeline executions.

#### 2. awareness of power

- Since the project didn't reach yet the v1.0, it is suggest to consult the documentation, the man page, the design choices in the Assembly [source](uzpexec.asm) code and the comments, the coverage of [tests.sh](tests.sh) by `make tests` in [Makefile](Makefile).

- Last but not least the [licensing](#licensing-terms) terms, which allows everyone to change the code (also at running time) but not to remove the authorship note, not even from the binary executable form. A powerful tool requires awareness about how to use it.

#### 3. files easy to find

- Suggested file extension: **`.uzp`**

---

### How to compile

Compiling `.asm` files requires `nasm`, otherwise `sudo apt install nasm` if missing:

```sh
make tests
```

Test by yourself and then decide how to deploy.

- `{ cat uzpexec; zstd -19c $elf; }   > $elf.uzp`
- `cp uzpexec $elf.uzp; gzip -c $elf >> $elf.uzp`
- `wget $url/$elf[.gz] -O- | uzpexec [args]`
- `uzpexec <&-||echo` # for the version + github

It works as a single block 512-bytes self-inflating executable payload replacing also `gzcmd.sh` with the sole requirement of `/bin/zcat` available.

---

### Python support

Using `sed` to change the interpreter from `/bin/sh` to every other available interpreter, the `uzpexec` can inflate and execute also non-shell scripts. Packaging a `.pyz` is a trivial procedure:

```sh
rm -f uzpexec; make uzpexec
export WORLD="Wonderful"; bin="hello.py"; cp -f uzpexec ${bin}z
pigz -11mc $bin >>${bin}z && chmod +x ${bin}z && ./${bin}z Nice

    Hello Nice World!
    lsfd: 0 1 2 3 9
    args: 'Nice'
    HOME: '/home/roberto'
    WORLD: 'Wonderful'

du -b hello.py*

    1370  hello.py
    1235  hello.pyz <-- the output is smaller than original !!!
```

In v0.95 or before, supporting python scripts was possible only by properly customising `uzpexec`. After, by system changes like configuring the `/bin/sh` or Linux `binfmt` to properly routing shebang-ed scripts to their own interpreter. Which is the standard configuration in desktop and servers and some less-than-minimal embedded systems.

---

### BusyBox support

> [!WARNING]
> 
> Currently BusyBox `uzcat` alias `zcat` with seamless decompression fully supports **only** few of the available algorithms, and in particular it has not `zstdcat`. However, having `zstdcat` is not indispensable for `zstd` inflating but passing `/proc/self/fd/9` to `u|zcat` (v0.98.2).

Integrating [#37ab6ac38](https://github.com/robang74/busybox/commit/37ab6ac38ffec8dad72f067d083104a39a99529b) (0.1Kb) to busybox [uchaosys](https://github.com/robang74/busybox) edition, `/bin/uzcat` is created as an applet and its link signals that it can by magic-number auto-detection decompress any supported format by busybox. This allows `uzpexec` as stub to work "seamlessly" with any compression format (gz, bz2, xz, lzma) without further customisation, while the uncompressing algorithms are already included in BusyBox.

Moreover, by the integration of the `/bin/uxsh` applet (0.4Kb) in BusyBox, the `uzpexec` should no longer care about carrying the proper interpreter full path when it stubs as a launcher script. Calling directly `/bin/uxsh` the shebang line will be used to call the defined interpreter. This applet isn't strictly necessary because `binfmt_script` might be missing in some embedded or lightweight system (or secured systems that do not allow `chmod +x` on `/proc/self/*`).

---

### Example #1

An example of use is related to this [project](https://github.com/robang74/uchaosys/blob/v074/qemu/README.md) about QEMU footprint reduction which uses `uzpexec` to deliver the executable binary in `UZP` format which can be downloaded from [here](https://github.com/robang74/working-in-progress/tree/main/uchaosys.qemu)

> [!NOTE]
> 
> The `qemu-system-x86_64`, provided in `UZP` self-inflate executable, appears to be an x86 ELF 32-bit LSB executable. That type file refers to the extractor. While qemu is expanded in RAM and execute in its original ELF 64-bit format.

### Example #2

The shell script [uzpack.sh](uzpack.sh) converts a binary or a script into a self-extracting self-running in memory only. The most natural test is using the script to convert itself. Which is what happens during `make` and the result can be found as `uzpack` (2.7Kb circa).

Obviously, it is possible to convert an already converted binary. Which fails to run when it carries a shell script, but it is acceptable because it is totally useless to convert anything twice, especially in this case.

> [!NOTE]
> 
> Performance report: `uzpexec` in "fork loop" mode, is capable of sucking 2 core power from my i5-8365. Two! And this number can correctly taken as an index of its performance: no any lags but pure execution.

---

### Quick customisation

Quick customisation by coreutil `sed`, or any other strings-based editor (or commands line combination like `xxd` or `base64` with busybox `sed` or `awk`) which can deal with binary data containing '\0', is straightforward supported:

```sh
rm -f uzpexec hello; make distclean uzpexec hello; elf=hello
sed -e 's/zstdcat.\{7\}U238/xzcat\x00_2_4_6_8x238/' uzpexec > $elf.uxp
xz -9c $elf >>$elf.uxp && chmod +x $elf.uxp && strace -f ./$elf.uxp 2>&-
```

It is worth to note the relevant role of the `U238` as string length sentinel:

- `U238 --> x238` to inform the running code about the customisation
- between `zcat_cat` and `eof_tests` data size can change, `U238` tags it 

Alternatives to `/bin/zstdcat` are every equivalent executable for which its full pathname would fit into a 22 chars string plus the trailing `\0`, and it can contain `/usr/local/bin/zstdcat`, for example.

When compiled with `_HAS_PROVIDER` and `_NO_INFOSIX` boolean declarations, the full pathname length remains unchanged. Depending on the compilation, the length can vary between 16 and 28 chars plus the ending `\0`.

```asm
; ==============================================================================
; COMPACT DATA SECTION (appended to code)
; ==============================================================================
;                                                                  LN | XE
copy_vers:  db "(c) github/robang74/uzpexec v0.98"              ;  33 | 33
%ifdef  _HAS_PROVIDER
provider :  db  0x20, "12345678", 0x0a                          ;  10 |  -
%else
micro_ver:  db        ".2", 0x20, 0x0a                          ;   - |  4
%endif
; following fields are conditionally overwritable, do unions
zcat_path:  db "/bin/z"
zcat_cmd :  db "std"
zcat_cat :  db "cat", 0                                         ;  13 | 23 (29)
%ifndef _HAS_PROVIDER
    times 6 db 0                                                ;   - |  -
%endif
%ifdef  _NO_INFOSIX
    times 6 db 0                                                ;   - |  -
%endif
eof_tests:  db "U238"                            ; for tests    :   4 |  -
; This introduces the need of having the /proc mounted,granted after the /init
; The shorter alernative is /dev/fd/9, but it is NOT grated on embedded systems
commd_exe:  db "/proc/self/"
file_desc:  db "exe", 0,0                                       ;  16 | 16
                                                                ; ----------
                                                                ;  76  tot.

; ==============================================================================
; PADDING: Aligned exactly to 512 bytes (dd skip=1)
; ==============================================================================
file_end:                       ; Physical end of the binary file!
times (512 - ($ - $$)) db 0     ; Padding to 512 bytes for skip=1
```

Since `/path/name` can point to a shell script, it can be changed to pair the input with the proper decompressing tool. While a tiny `xcat` binary in ASM would be much faster in properly pairing the matches.

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

From the desktop user perspective the GNU coreutils `sed` command, or a specific shell script, can properly deal with elf and different script interpreters like python. Installing the [zutils](https://www.nongnu.org/zutils/zutils.html) the alternative `zcat` is able to autodetect the compression format and act accordingly.

From the system integration perspective, the approach explained in the [busybox support](#busybox-support) section would deal with different decompressing formats and selecting the proper script interpreter on the fly, bypassing the `binfmt_script` settings and replacing zutils `zcat` with a tiny footprint.

Hence, the customisation can scale up to completely different usage and deploying paradigms while still relying on the same basic tools and `uzpexec` strings embedded in the .data section.

#### Quick deploy view

The execution by pipe allows a basic running system, then an app is piped into `uzpexec` and executed accordingly with its nature and compression format. And this is a great feature for a lightweight supervisor OS that can create separated virtual execution spaces for each app granting that there is no absolute way one can sniff or read data from the others (unless system vulnerabilities, obviously, but not for the design of the uzpexec).

As a standalone utility `uzpexec` doesn't need to subdue the strict `dd skip=1` constraint, being just an utility on a system. And this explains why the full version for ARM64 is totally fine being 1Kb or whatever minimal size, while the stub (two different for elf and scripts) are designed for the same constraint of the x86 counterpart. Knowing that x86 is for data-centers and arm64 for mobile devices.

#### Quick ELF32 view

Just to have an idea of the compacting everything in a 1-dd-block challenge,
this following schema shows the sections within the 512-byte binary file in
which the effective code area is necessarily compressed between the headers
and the static data stored in the bottom part: 320 bytes are two 160 chars
GSM-era SMS with 8 bit/char text encoding, just to have an idea of the size.

```
 RAM ADDRESS      Stub/Payload 512 bytes, v0.95    DISK SIZE

 0x08048000 -- +---------------------------------+ -- 0x0000
               |  ELF Header          |   52 B   |
 0x08048034 -- +---------------------------------+ -- 0x0034
               |  Program Header      |   32 B   |
 0x08048054 -- +---------------------------------+ -- 0x0054
               |  Machine Code        |  320 B   |
               | (start -> exit)      |          |
 0x08048194 -- +---------------------------------+ -- 0x0194
               |  Embedded Data:      |  105 B   |
               |  version, provider,  |          |
               |  paths, args, etc.   |          |
 0x080481FD -- +---------------------------------+ -- 0x01FD
               |  Padding (zeros)     |    3 B   |
 0x08048200 -- +---------------------------------+ -- 0x0200
               |  .bss (RAM only)     |  not in  |
               |   buf[516]           |   file   |
               +---------------------------------+
```

Customising this little guy is easy because the data is stored in plain text
which can easily be changed by a `sed` command line but altering the byte code
to change its running behaviour or logic, is completely another story.

#### Quick ARM64 view

The [uzarm64.arm](uzarm64.arm) for aarch64 is a 512-byte stub/payload function-tuned created by refactoring down from the full 1024-bytes [uzpexec.arm](uzpexec.arm) version, introduces some limitations to cut down its size:

- it uses `argv[0]` as filename
- just gzipped elf by `execve()`
- `qemu-aarch64`'s bug friendly
- still has the provider field

Potentially separating the ELF binary from script support, it is reasonable to have two stubs both `dd` single-block size that a script like [zpack.sh](zpack.sh) can embed as payload and deploy each of them selectively.

```sh
$ make testb
$ export WORLD=Wonderful
$ { cat uzarm64; gzip -9c hello; } > hiwld && chmod +x hiwld
$ ~/bin/qemu-aarch64-static -d strace ./hiwld nice
```
```
    1147131 prctl(38,1,0,0,0,0) = 0
    1147131 prctl(4,0,0,0,0,0) = 0
    1147131 openat(AT_FDCWD,"/proc/self/exe",O_RDONLY|O_CLOEXEC) = 4
    1147131 memfd_create(124085102814410,3,524288,0,0,0) = 5
    1147131 read(4,0x400200,512) = 512
    1147131 clone(0x11,child_stack=0x0000000000000000,
            parent_tidptr=0x0000000000000000,tls=0x0000000000000000,
            child_tidptr=0x0000000000000000) = 1147134
    1147131 wait4(-1,0,0,0) = 0
    1147134 dup3(4,0,0) = 0
    1147134 dup3(5,1,0) = 1
    1147134 execve("/bin/zcat",{"/bin/zcat",NULL}) =
    1147131 fcntl(5,F_ADD_SEALS,0x000000000000000f) = 0
    1147131 execve("/proc/self/fd/5",{"./hiwld","nice",NULL})
    Hello nice World!
      ARGV0: './hiwld'
       ARGC: '2'
       HOME: '/home/roberto'
      WORLD: 'Wonderful'
```

The above reported console commands and output provide a reference about the running of a simple ARM64 compressed elf, the system call involved, the args/envp management and last but not the simplicity of assembling it.

#### Performance test

The use of `uzpexec` extends every GitHub action from executing whatever is installable by their internal repository to whatever is available by an URL access, adding a negligible latency, in terms of human perception. By contrast, the variance of the latency (rng/min) is reduced up to 6 folds.

```
QUICK TESTS ON v0.98.1

Stats are made on the 10 sample 1s away after the first (for cache) call

Case #1: qemu 38.8MB w/ 1st degree dynamic libraries

time qemu-system-x86_64 -m4 2>&-

    real  min:  9, avg: 19.7, max: 36 (ms)
    user  min:  4, avg:  7.2, max: 13 (ms)
    sys   min:  3, avg: 12.5, max: 25 (ms)

Case #2: qemu 7.5MB musl-static, 2.5MB zstd compressed

time ./qemu-system-x86_64 -m4 2>&-

    real  min: 40, avg: 43.0, max: 59 (ms)
    user  min: 18, avg: 22.6, max: 30 (ms)
    sys   min: 20, avg: 24.6, max: 34 (ms)

uzpexec executes a binary which has already uzpexec as loader

time cat ./qemu-system-x86_64 | ./uzpexec -m4 2>&-

    real  min: 37, avg: 47.7, max: 86 (ms)
    user  min: 21, avg: 27.4, max: 45 (ms)
    sys   min: 18, avg: 27.6, max: 55 (ms)

uzpexec executes by STDIN pipe a binary which is zstd compressed

time dd skip=1 if=qemu-system-x86_64 2>&-| ./uzpexec -m4 2>&-

    real  min: 30, avg: 37.8, max: 48 (ms)
    user  min: 18, avg: 23.8, max: 35 (ms)
    sys   min: 18, avg: 25.6, max: 40 (ms)

Quick tests aim to set a raw reference in differential launch latency

```

By a raw estimation a 1GBit/s network call is nearly equivalent to a local call, because the 1Gbit/s network transfer time (25 ms) is zeroed by decompression on stream. Moreover, considering that `zstd` inflates at 1GB/s, the 23 ms of average latency overhead are spent almost entirely (96%) in the `fork()` and `exec()` of the external decompressing tool.

| Throughput (MB/s) |   min |   avg |   max |    r% | latency (ms) |
|-------------------|------:|------:|------:|------:|:------------:|
| `zstdcat`         |   263 |   324 |   356 |   100 |   23 (real)  |
|||||||
| `busybox zstd`    |   138 |   170 |   285 |    52 |   46 (ext.)  |
| `zcat`            |   105 |   172 |   200 |    53 |   46 (ext.)  |
| `pigz -p8 -dc`    |   116 |   176 |   215 |    54 |   46 (ext.)  |
|||||||
| `xzcat`           |    43 |    50 |    52 |    15 |  149 (ext.)  |
| `busybox zcat`    |    72 |    91 |   111 |    28 |   80 (ext.)  |
| `busybox xzcat`   |    46 |    47 |    48 |    28 |  158 (ext.)  |

The `zstdcat` isn't available in BusyBox but its `zcat` supports it by seamless file decompression and this is the **only** way in which an embedded system can compensate for a 4x slower latency in execution start. Unfortunately, BusyBox seamless decompression isn't working with pipe.

#### Compression speed

Clearly, the `zstd` strongest advantage in this specific case (executable) is about the decompression speed because in all the other dimensions also the BusyBox `gzip` performs very well.

| Compression (ELF x86 64-bit, 7265KB)     | size | time     |
|------------------------------------------|-----:|---------:|
| `time xz    -9c qemu-system-x86_64.elf`  | 2064 |  2.564 s |
| `time pigz -11c qemu-system-x86_64.elf`  | 2492 | 16.763 s |
| `time zstd -19c qemu-system-x86_64.elf`  | 2223 |  2.804 s |
| `time xz    -1c qemu-system-x86_64.elf`  | 2266 |  0.620 s |
||||
| `time pigz  -9c qemu-system-x86_64.elf`  | 2590 |  0.169 s |
| `time zstd  -9c qemu-system-x86_64.elf`  | 2477 |  0.220 s |
||||
| `time busybox gzip -9c $qemu_x86_64.elf` | 2607 |  0.349 s |

Or said from another perspective BusyBox `zcat` has a bottleneck to fix and more in general, the `gunzip` algorithm should be reviewed in order to evaluate a 2x faster refactored implementation. The two might converge as much as a new BusyBox `gunzip` implementation might achieve a 4x speed improvement.

#### Parallel ungzip

The most impactful constraint in embedded system is that a core component like BusyBox cannot be easily updated as per someone whish while adding a tiny ELF binary and leveraging a back-compatible compressing format are the key for boosting inflating performance also in legacy systems with as low as possible impact and effort.

```sh
time ({ for i in $(seq 0 7); do
dd bs=1M count=1 skip=$i if=qemu-system-x86_64.elf |
gzip -9c > qemu.$i & done; } 2>&1 | cat >/dev/null)

    real  0m0.036s     <-- 4.69 times faster (!!!)
    user  0m0.006s
    sys   0m0.021s

cat qemu.[0-7] | wc -c

    2655233            <-- 2593KB (+3KB, +0.12%)

du -b qemu.? | cut -f1 |  tr '\n' ' '

    514999 457580 535821 396935
    205692 396576 132445  15185

time for i in $(seq 0 7); do
  ./busybox gzip -dc qemu.$i >/dev/null & done |
      cat >/dev/null

    real	0m0.017s     <-- 5.80 times faster (!!!)
    real	0m0.025s     <-- 4.00 times faster
```

Under this perspective the parallel inflating requires appending a table like:

| size    | record meaning                 |
|---------|--------------------------------|
| 16 bits | size of the uncompressed chunk |
| 32 bits | a record for each chunk        |
| 16 bits | size of this table             |
| 32 bits | a CRC32 code for the table     |
| 32 bits | an ending magic number         |

For a 8 chunks gziped file the raw data sum up to a maximum of 44 bytes while the `gzip` header is usually 18 bytes. Therefore, a proper field size calibration works better than compressing the table. Trailing "garbage" is ignored by standard `gzip` which would process a sequence of compressed chuck as sequential streams. Hence, this format extension is 100% back-compatible.

Considering that uncompressed chunk can be 512 bytes fine-grained, the max chuck size could be 32MB, while 32 bit record addresses are additive. Accepting a limitation of 16MB per chunk, each records can be encoded in 24 bits saving 8 bytes for 8 chunks. Since 32 bit alignment is easier faster to read and to decode, the speed is the main goal, the first record is 32 bit aligned as well and just the lower 16 bits are used.

Finally, the hurd of 8 instances of `gzip` seems way faster than a single `pigz` 8 threads and this result isn't convincing me completely. However, unless further deeper investigation would not confute this number, it stays as reference.

| Scenario                            | Time      | Note                      |
|:----------------------------------- |:---------:|:------------------------- |
| Sequencial  `>/dev/null` (RAM-only) |  99 ms    | Pure CPU-bound            |
| Parallel 8x `>/dev/null` (RAM-only) | 17–25 ms  |  **Speedup 4–5.8x**       |
| 8x `dd bs=1M seek notruc of=$file`  |  56 ms    | I/O-bound, VFS contention |

The overall outcome can be improved using a script with `--tries N` which using `gzip -1` determines a good enough number of chunks for a determined parallelisation range. In fact, the list of the compressed chunk sizes above shows an unbalanced mix and in particular the last one is just 15KB which is a waste of an entire thread or fork/exec over 8. In theory, a 7 balanced threads (plus one for their father) would provide a 6x performance in RAM-only inflating.

---

### Trivial facts

- Security is a matter of perception, mainly. Currently, more a bureaucratics market rather than a serious R&D field. Hence, it is *destabilising* seeing an independent developer combining and surfacing 10-20yo techniques that relates to: TeenyELF (2005, darkweb), `memfd_create()` and `execveat()` (2014 and 2015, Linux) in glibc (2018).

- A 64 bit ELF would be much bigger, 2x potentially, and adding no value because this ELF32 doesn't process anything, not even the read() / write() hot loops (since the zero pipes implementation) but just a few system calls.

- The `uzpexec` has been developed to compensate for the gzcmd.sh shortcomings and to add useful capability in dealing with STDIN pipe. So, the `gzcmd.sh` is this project's MVP to reach the production grade with `uzpexec`.

- Every sane compressing algorithm is also self-validating in terms of output conformity with the original while executing from a url in pipe is popular but a dangerous action because man-in-the-middle attack.

- Is `uzpexec` a stub or a payload or a pipexec? All of them, depending on the role it plays. When it gets [embedded](https://github.com/robang74/uzpexec/blob/master/uzpack.sh#L42) in `uzpack.sh` it is a payload, when `uzpack.sh` converts itself, it is a stub. When it is used vanilla is a pipexec.

- Moreover, all these three roles are complementary and necessary. Without pipexec it would not be able to run compressed scripts, hence it would not be able to convert itself. But it does, hence it is also a stub and a payload.

- This triade of roles, and related capabilities, underlines why `uzpexec` isn't limited by the *unzip-and-run* goal, which is the `uzpack` main pourpose. It is different by design, by audience, by roles.

---

### WRX memory

Separating executable code (X) from writing memory (W) costs too many bytes of code in stubs when a proper design can prevent any practical exploitation of that memory by an *unprivileged enough* attacker (aka before privileges escalation happens, aka for `uzpexec` not being the primary vector because this W+X memory design).

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

Sealing in RO the anonymous file descriptor before execve() strongly supports security and integrity of the code/script set to run by `uzpexec`.

```txt
  ; ----------------------------------------------------------------------------
  ; HARDENING: F_ADD_SEALS TO MEMFD
  ;
  ; Apply F_ADD_SEALS (F_SEAL_WRITE, etc.) to the memfd exclusively
  ; within the ELF execution path before invoking execveat().
  ;
  ; - ELF hardening: prevents any runtime exploits from tampering with
  ;   or rewriting the binary payload resident in RAM via /proc/self/fd/.
  ;
  ; - Script compatibility: this security measure is omitted for the
  ;   shell interpreter branch because /bin/sh and its sub-utilities
  ;   often require standard read/write descriptors or create temporary
  ;   files, meaning write-restricted seals could break compatibility.
  ; ----------------------------------------------------------------------------
```

A couple more of constraints strengthen the overall security policy:

```txt
  ; ----------------------------------------------------------------------------
  ; HARDENING: NO_NEW_PRIVS & ANTI-CORE-DUMP
  ;
  ; Using umask() is omitted because memfd ignores filesystem permissions.
  ; Additional hardening:
  ; - prctl(NO_NEW_PRIVS) prevents SUID escalation,
  ; - prctl(PR_SET_DUMPABLE, 0) prevents core dumps,
  ; - F_SEAL_SEAL locks the memfd seals permanently,
  ; - MFD_CLOEXEC and F_SEAL_WRITE are already set.
  ; ----------------------------------------------------------------------------
```

#### Script to ELF32

- every script is supported when provided by its own shebang
- the related interpreter is registered with `binfmt_scripts`

```sh
#!/bin/sh
# ------------------------------------------------------------------------------

            # ############################################### #
            # ####### put your shell script code here ####### #
            # ############################################### #

# ------------------------------------------------------------------------------
exit $ret
```

Since `/bin/dash` is far faster than `/bin/bash` is usually the default shell on most
Linux desktop installations and almost always available.

By contrast, [gzcmd.sh](#gzcmdsh) is designed to create self-extracting executable scripts.
Therefore, when the script is complex, implements bashisms, or performs peculiar activity with/by the console, or requires to be self-finding or self-editing as standard file by its executable path then [gzcmd.sh](gzcmd.sh) is a solid way to go.

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
$ UZCMD=pigz ZCMPLVL=11  sh gzcmd.sh gzcmd.sh
FILE: 'gzcmd.gz.sh', HEAD: 506 (512), GZIP: 6635 (6 Kb, 37 %), GZSH: v0.3.3

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

