.PHONY: blkln

TARGETS := gzcmd.gz.sh upexec

all: blkln $(TARGETS)

blkln:
	@echo

gzcmd.gz.sh: gzcmd.sh
	@echo $^ self-compressing
	sh $^ $^
	du -b $@
	@echo

upexec: upexec.asm
	@echo compiling $^
	nasm -O2 -f bin $^ -o $@
	file $@
	du -b $@
	@echo

clean: blkln
	rm -f $(TARGETS)
	@echo
