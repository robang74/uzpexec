# Makefile for uzpack / uzpexec
#
# (c) 2026 Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2 license
#
################################################################################

.PHONY: blkln tests upexec

TARGETS := gzcmd.gz.sh uzpexec hello uzpack
ZDDCMD  := dd if=hello.gz.sh skip=1 | zcat

all: tests

blkln:
	@echo

gzcmd.gz.sh: gzcmd.sh
	@echo ====== $^ self-compressing ======
	@echo
	sh $^ $^
	du -b $@
	@echo

uzpexec.1: | uzpack.1
	ln -sf $^ $@

uzpexec: uzpexec.asm | uzpexec.1
	@echo ====== compile $^ ======
	@echo
	nasm -O2 -f bin $^ -o $@
	@chmod +x $@
	file $@ | sed -e 's/V), s/V),\n\ts/'
	du -b $@
	@echo

hello: hello.c
	@echo ====== compile $^ ======
	@echo
	cc -s -Os $^ -o $@ -Wl,--build-id=none
	file $@ | sed -e "s/, int/,\n\t int/"
	du -b $@
	@echo

uzpack: uzpexec uzpack.sh
	@echo ====== produce $@ ======
	@echo
	sh uzpack.sh -u uzpexec
	@rm -f uzpack
	sh uzpack.sh uzpack.sh uzpack
	du -b $@
	@echo

clean: blkln
	rm -f $(TARGETS) hello.gz.sh ls.elf ls.gz.elf
	rm -f tests.res uzpack.uzp uzpexec.uzp uzpexec.1
	@echo

tests: blkln $(TARGETS)
	@echo ====== testing hello ======
	@echo
	./hello
	@echo
	@echo ====== testing gzcmd.gz.sh ======
	@echo
	./gzcmd.gz.sh hello
	./hello.gz.sh
	@echo
	@echo ====== testing uzpexec ======
	@echo
	sh tests.sh --tests-only

