.PHONY: all

all: zrlerun zlz4run zb77run
	@echo

zrlerun: zrlerun.asm
	@echo
	nasm -s -O2 -f bin $^ -o $@
	{ cat $@; time -p python3 zrlezip.py /bin/ls - ;} > lrz
	gzip -1c /bin/ls > ls.gz
	du -b lrz ls.gz /bin/ls $@
	chmod +x lrz && ./lz -al lrz

zlz4run: zlz4run.asm
	@echo
	nasm -s -O2 -f bin $^ -o $@
	{ cat $@; time -p python3 zlz4zip.py -l 12 /bin/ls - ;} > l4z
	gzip -9c /bin/ls > ls.gz
	du -b l4z ls.gz /bin/ls $@
	chmod +x l4z && ./l4z -al l4z

zb77run: zb77run.asm
	@echo
	nasm -s -O2 -f bin $^ -o $@
	@echo "Compressing, VERY slow, wait..."
	{ cat $@; time -p python3 zb77zip.py -l 9 /bin/ls - ;} > l7z
	gzip -9c /bin/ls > ls.gz
	du -b l7z ls.gz /bin/ls $@
	chmod +x l7z && ./l7z -al l7z

clean:
	@echo
	rm -f lrz l4z l7z zrlerun zlz4run zb77run
