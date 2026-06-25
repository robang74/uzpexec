## RLE

> [!WARNING]
>
> This ASM code, despite being based on [uzpexec](../uzpexec.asm), is in its early stage of development. Hence should be considered for experiments only.

A very simple example with `/bin/ls`

```sh
bin=zrlerun
nasm -s -O2 -f bin $bin.asm -o $bin && du -b $bin
{
  cat $bin; python3 zrlezip.py /bin/ls -
} > lz && chmod +x lz && ./lz -al
```

It shows the bare fact that a "short code" inflater doesn't match the pair with
strong level of compression. In this case achieve 1/2 of gzip compression which
isn't the most stronger compression we can choose, but at the price of code size.

```sh
bin=zrlerun
pys=zrlezip.py
nasm -s -O2 -f bin $bin.asm -o $bin && du -b $bin
{
  cat $bin; python3 $pys $pys -
} > pz && chmod +x pz && ./pz -h

echo; ./lz -al
```

With the text the RLE doesn't perform better at all. In fact the compressed python
script is just a little smaller in size and once payloaded with the 512-bytes ELF32
it is bit bigger than the original. However, in principle it works.

<br>

## LZ4

> [!WARNING]
>
> This ASM code, despite being based on [uzpexec](../uzpexec.asm), is in its early stage of development. Hence should be considered for experiments only.

Example:

```sh
bin=zlz4run
nasm -s -O2 -f bin $bin.asm -o $bin && du -b $bin
{
  cat $bin; python3 zlz4zip.py /bin/ls -
} > lz && chmod +x lz && ./lz -al
```

It doesn't match `gzip` but this simplified LZ4 version is way better than LRE one.

```sh
bin=zlz4run
pys=zlz4zip.py
nasm -s -O2 -f bin $bin.asm -o $bin && du -b $bin
{
  cat $bin; python3 $pys $pys -
} > pz && chmod +x pz && ./pz -h

echo; ./lz -al
```

It starts to make sense for compressing scripts and let them like they were binaries.

Requires:

```sh
pip install lz4
```

In extracting the LZ4 blob, the ELF32 allocates 4MB of RAM, a way more than RLE.


