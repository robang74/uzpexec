# zRLE

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
