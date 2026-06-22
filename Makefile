.PHONY: blkln tests

TARGETS := gzcmd.gz.sh upexec hello
ZDDCMD  := dd if=hello.gz.sh skip=2 | zcat

all: tests

blkln:
	@echo

gzcmd.gz.sh: gzcmd.sh
	@echo === $^ self-compressing ===
	@echo
	sh $^ $^
	du -b $@
	@echo

upexec: upexec.asm
	@echo === compiling $^ ===
	@echo
	nasm -O2 -f bin $^ -o $@
	@chmod +x $@
	file $@
	du -b $@
	@echo

hello: hello.c
	@echo === compiling $^ ===
	@echo
	cc -s -Os $^ -o $@ -Wl,--build-id=none
	file $@ | sed -e "s/, int/,\n\t int/"
	du -b $@
	@echo

clean: blkln
	rm -f $(TARGETS)
	@echo

tests: blkln $(TARGETS)
	@echo === testing hello ===
	@echo
	./hello
	@echo
	@echo === testing gzcmd.gz.sh ===
	@echo
	./gzcmd.gz.sh hello
	./hello.gz.sh
	@echo
	@echo === testing upexec ===
	@echo
	export WORLD=beatiful; $(ZDDCMD) | ./upexec $WORLD
	@echo
