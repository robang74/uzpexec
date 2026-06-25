.PHONY: all

all: zrlerun zlz4run
	@echo

zrlerun: zrlerun.asm
	@echo
	nasm -s -O2 -f bin $^ -o $@
	{ cat $@; python3 zrlezip.py /bin/ls - ;} > lrz
	gzip -1c /bin/ls > ls.gz
	du -b lrz ls.gz /bin/ls $@
	chmod +x lrz && ./lz -al lrz

zlz4run: zlz4run.asm
	@echo
	nasm -s -O2 -f bin $^ -o $@
	{ cat $@; python3 zlz4zip.py -l 12 /bin/ls - ;} > l4z
	gzip -9c /bin/ls > ls.gz
	du -b l4z ls.gz /bin/ls $@
	chmod +x l4z && ./l4z -al l4z

clean:
	@echo
	rm -f lrz l4z zrlerun zlz4run
