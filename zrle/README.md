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

<br>

## BLZ

> [!WARNING]
>
> This ASM code, despite being based on [uzpexec](../uzpexec.asm), is in its early stage of development. Hence should be considered for experiments only.

In this case the memory limit is set to 4MB as much as the LZ4 which remains the best among these three options.

<br>

## 123

Executing `make clean all` the output is self-explicative: LZ4 is the favourite.

```txt
nasm -s -O2 -f bin zrlerun.asm -o zrlerun
{ cat zrlerun; time -p python3 zrlezip.py /bin/ls - ;} > lrz
Compressed 138216 bytes down to 116716 bytes.
real 0.06
user 0.06
sys 0.00
gzip -1c /bin/ls > ls.gz
du -b lrz ls.gz /bin/ls zrlerun
117228	lrz
62203	ls.gz
138216	/bin/ls
512	zrlerun
chmod +x lrz && ./lz -al lrz
-rwxrwxr-x 1 roberto roberto 117228 Jun 25 13:58 lrz

nasm -s -O2 -f bin zlz4run.asm -o zlz4run
{ cat zlz4run; time -p python3 zlz4zip.py -l 12 /bin/ls - ;} > l4z
real 0.04
user 0.04
sys 0.00
gzip -9c /bin/ls > ls.gz
du -b l4z ls.gz /bin/ls zlz4run
70863	l4z
58555	ls.gz
138216	/bin/ls
512	zlz4run
chmod +x l4z && ./l4z -al l4z
-rwxrwxr-x 1 roberto roberto 70863 Jun 25 13:58 l4z

nasm -s -O2 -f bin zb77run.asm -o zb77run
Compressing, VERY slow, wait...
{ cat zb77run; time -p python3 zb77zip.py -l 9 /bin/ls - ;} > l7z
real 7.77
user 7.75
sys 0.01
gzip -9c /bin/ls > ls.gz
du -b l7z ls.gz /bin/ls zb77run
68965	l7z
58555	ls.gz
138216	/bin/ls
512	zb77run
chmod +x l7z && ./l7z -al l7z
-rwxrwxr-x 1 roberto roberto 68965 Jun 25 13:58 l7z
```

We can immediately discard LRE, while LZ4 scores 51% vs 42% (lover is better).

The best LZ4 can do remains 14% bigger than the worse that GZIP can do.

