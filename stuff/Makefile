upexec: upexec.asm
	@echo ====== compile $^ ======
	@echo
	nasm -O2 -f bin $^ -o $@
	@chmod +x $@
	file $@
	du -b $@
	@echo
	@echo ====== testing $^ ======
	@echo
	export WORLD=beatiful; $(ZDDCMD) | ./upexec $$WORLD
	@echo self-check:
	printf xyz | ./upexec; echo error: $$? | sed -e 's/: 4/& OK/'
	printf 'x%.0s' {1..256} | ./upexec; echo error: $$? | sed -e 's/: 4/& OK/'
	echo "error: 0 "$$(./upexec<&-; test $$? -eq 0 && echo OK || echo KO)
	@echo
