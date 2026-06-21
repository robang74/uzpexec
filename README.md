# gzcmd.sh

A shell script that converts any ELF in a self-extracting executable for standard Unix/POSIX systems

- Initially written and committed in this repository [Bare Minimal Linux Kernel & RootFS](https://github.com/robang74/bare-minimal-linux-system) &nbsp;(2026-02-17)

<br>

### Usage

Alternatively it can be used by activating the execution bit by `chmod +x gzcmd.sh` or calling it by the shell `sh gzcmd.sh`, the only parameter that matters is the ELF patch to convert and the converted file will be written in the current directory.

```sh
$ sh gzcmd.sh gzcmd.sh
FILE: 'gzcmd.gz.sh', HEAD: 863 (1024), GZIP: 7439 (7 Kb, 42 %), GZSH: v0.2.0
```

To use the converted file, launch it directly or by a shell because from the PoV of the Linux kernel is a shell script.

<br>

### Payload

The payload size is always 1024 (two 512 blocks) because such a default value allows a trivial extraction of the gzipped appended file:

```sh
dd skip=2 if=${filename.gz.sh} | zcat - >${filenme}
```

The payload is specific for every converted file but potentially can be generalised removing the following line:

- `MD5="$MD5CKSUM";BFN="$ORIGNAME";SZE="$((ORIGSIZE>>10))k"` (remove)

and for a more shorter version replacing the following line with a graph `{` parentesys:

- `$GZCSUMCK "\$_fn"|grep -qe "^\$MD5"||{` --> `{` (replace)

I will be shorter and faster to execute but every time it will extract the ELF, therefore losing the install:

- `GZCTMP=~/bin ./$namefile,gz.sh` --> install in ~/bin

The three padding lines provide `20 x 80 = 240` bytes to reach the 1024 fix size, shortening more the payload, requires adding more lines, unless the size drops below 512 bytes and in that case `bs skip=1` would be enough.

On a fully controlled system the payload can be as shorter as the code used for extracting the gzipped load.
