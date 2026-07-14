#
# (c) 2026 Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2 license
#
################################################################################

# -----------------------------------------------------------------------------
# Standard directories
# -----------------------------------------------------------------------------
PREFIX    ?= /usr/local
DESTDIR   ?=
BINDIR     = $(DESTDIR)$(PREFIX)/bin
MANDIR     = $(DESTDIR)$(PREFIX)/share/man/man1
DATADIR    = $(DESTDIR)$(PREFIX)/share/uzpack
SRCDIR     = $(DATADIR)/src

# -----------------------------------------------------------------------------
# Package metadata
# -----------------------------------------------------------------------------
VERSION   ?= 0.95
PKGNAME    = uzpexec
FILENME    = $(PKGNAME)-$(VERSION)
ARCH       = $(shell dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null || uname -m)
MAINTAINER = Roberto A. Foglietta <roberto.foglietta@gmail.com>

# -----------------------------------------------------------------------------
# Files
# -----------------------------------------------------------------------------
BINS       = uzpexec uzpack gzcmd.gz.sh
CLEN       = uzpexec hello hellz uzpeck uzpeck.uzp
MANPAGES   = uzpack.1 uzpexec.1
DOCFILES   = README.md uzpack.md
DEVFILES   = uzpack.sh uzpexec.asm uzpexec.arm hello.c hello.sh hello.py
DEVFILES  += tests.sh sigsegv.c gzcmd.sh Makefile $(DOCFILES) zeroenv.c
RPMFILES   = $(BINS) $(MANPAGES) $(DEVFILES) uzpexec.spec.tmpl

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

VERSNED   := uzpexec.spec.tmpl uzpexec.asm Makefile
VTOGREP   := $(VERSNED) uzpack.md uzpack.1
GRPDATE   := [0-9]\{4\}-[0-9][0-9]-[0-9][0-9]
GREPCOL   := grep --color=always

ZDDCMD    := dd if=hello.gz.sh skip=1 | zcat
GITMPLOG  := deb/changes.log

define version_change
	sed -e "s,\(github/robang74 \)v[0-9.]\{4\},\1v$1," \
	    -e "s,\(Version[:?= ]*\)[0-9.]\{4\},\1$1,I" -i $(VERSNED)
	sed -e "s,^v[0-9.]\{4\},v$1," -i uzpack.md
	sed -e  "s,v[0-9.]\{4\},v$1," -i uzpack.1
	sed -e "s,$(GRPDATE),$$(date +%F)," -i uzpack.1 uzpack.md
endef

define git_changes_log
	git log --abbrev-commit --date=short --format=format:'+ %h - %ad - %s %d' |\
	    grep --color=never tag $1
endef

define git_relevant_log
	sed -n -e 's/ *.HEAD -. .*//' -e 's/ *.tag: .*//' -e 's/^\+ /* /p'
endef

define grep_and_tab
	eval $1 2>&1| grep $2 | sed -e "s,^,\t,"
endef

# -----------------------------------------------------------------------------
# Build targets
# -----------------------------------------------------------------------------
.PHONY: all blkln tests clean install uninstall deb rpm

JE_STDIN ?= _DO_STDIN
JE_FORCE ?= _DO_FORCE
JE_EXTRA ?= _NO_EXTRA
JE_EXCVE ?= _N_EXECVE

all: $(BINS)

blkln:
	@echo

gzcmd.gz.sh: gzcmd.sh
	@echo ====== $^ self-compressing ======
	@echo
	sh $^ $^
	du -b $@
	@echo

uzpexec: uzpexec.asm
	@echo ====== compile $^ ======
	@echo
	nasm -d$(JE_STDIN) -d$(JE_FORCE) -d$(JE_EXTRA) -d$(JE_EXCVE) -O2 -f bin $^ -o $@
	@chmod +x $@
	ln -sf uzpack.1 uzpexec.1
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

zeroenv: zeroenv.c
	@echo ====== compile $^ ======
	@echo
	cc -s -Os $^ -o $@ -Wl,--build-id=none
	file $@ | sed -e "s/, int/,\n\t int/"
	du -b $@
	@echo

sigsegv: sigsegv.c
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
	rm -f uzpack
	sh uzpack.sh -9 uzpack.sh uzpack
	du -b $@
	@echo

deb/changelog: $(GITMPLOG)
	head -n2 $@.templ  >$@
	cat $^            >>$@
	tail -n2 $@.templ >>$@
	@echo

clean: blkln
	rm -rf deb/tmp uzpexec.spec.tmp uzpexec.spec
	rm -f tests.res uzpack.uzp uzpexec.uzp ls.elf
	rm -f hello.gz.sh ls.gz.elf lz uzpack.new
	@echo

utils: hello zeroenv sigsegv

doexecve:
	@echo ====== compile execve ======
	@echo
	rm -f uzpexec
	@echo
	( make JE_EXCVE=_USE_EXECVE uzpexec )| grep -ve "^==="
	@echo

testexve:
	@echo ====== testing execve ======
	@echo
	make doexecve hello >/dev/null 2>&1
	@echo
	{ cat uzpexec; gzip -9c hello; } > hellz
	chmod +x hellz
	$(call grep_and_tab,"strace ./hellz","execve[^a]")
	$(call grep_and_tab,"WORLD=Wonderful ./hellz nice",".")
	@echo
	$(call grep_and_tab,"sh uzpack.sh uzpack.sh uzpeck","generated: uzpeck")
	@echo
	$(call grep_and_tab,"strace ./uzpeck uzpack.sh uzpeck.uzp","execve[^a]")
	@echo
	$(call grep_and_tab,"./uzpeck.uzp -v","github/robang74")
	@echo
	rm -f $(CLEN)
	@echo

nostdin:
	@echo ====== compile nostdin + provider ======
	@echo
	rm -f uzpexec
	@echo
	( make JE_STDIN=_NO_STDIN JE_EXTRA=_DO_EXTRA uzpexec )| grep -ve "^==="
	@echo

teststdin: nostdin
	@echo ====== testing nostdin ======
	@echo
	@echo ret:2 is mandatorly expected
	timeout 1 ./uzpexec; printf "\tret:$$?\n" | grep -e "ret:2$$" || exit
	@rm -f uzpexec
	@echo

_tests: blkln teststdin testexve distclean utils $(BINS)
	@echo ====== testing hello ======
	./hello

	@echo ====== testing zeroenv ======
	@echo
	{ env -i sh -c "env" | sed -e "s,^,  ," | grep PWD && \
      ./zeroenv sh -c "env" | grep PWD; } || \
          printf "  PASS: ok\n"
	@echo

	@echo ====== testing sigsegv ======
	@echo
	echo "Y2lhbwo=" | { ./sigsegv /bin/base64 -d ||\
	  printf "\tERR: $$?\n" >&2; } | sed -e "s,^,  CIAO: &,"
	@echo

	@echo ====== testing gzcmd.gz.sh ======
	@echo
	./gzcmd.gz.sh hello
	./hello.gz.sh

	@echo ====== standalone uzpack.sh, p.1 ======
	@echo
	rm -f uzpack.new
	mv -f uzpack uzpack.bak
	mv -f uzpexec uzpexec.bak
	sh uzpack.sh uzpack.sh uzpack

	@echo ====== standalone uzpack.sh, p.2 ======
	@echo
	@echo TODO
	./uzpack uzpack uzpack.new
	mv -f uzpexec.bak uzpexec
	mv -f uzpack.bak uzpack
	rm -f uzpack.new
	@echo

	@echo ====== executing tests.sh ======
	@echo
	sh tests.sh --tests-only

tests:
	@make distclean >/dev/null 2>&1
	@make _tests
	@make distclean >/dev/null 2>&1

version: distclean
	@echo ====== VERSION: $(VERSION) ======
	@echo
	$(GREPCOL) -e '[" v][0]\.[0-9]\{2\}' $(VTOGREP)
	$(call version_change,$(VERSION))
	@echo
	$(GREPCOL) -e '[" v]'$(VERSION) -e "$(GRPDATE)" $(VTOGREP)
	@echo

# -----------------------------------------------------------------------------

armcross := aarch64-linux-gnu
armuqemu := qemu-aarch64-static
armloadr := $(shell which $(armuqemu))
armflags := --defsym $(JE_STDIN)=1 --defsym $(JE_FORCE)=1
armflags += --defsym $(JE_EXTRA)=1 --defsym $(JE_EXCVE)=1

hix86gz: uzprm64 hello
	rm -f $@
#	cc -s -static hello.c -o hix86s
	cp -f uzprm64 $@ && gzip -9c hello >> $@
	chmod +x $@
	@echo

hlx86gz: uzarm64 hello
	rm -f $@
	cp -f uzarm64 $@ && gzip -9c hello >> $@
	chmod +x $@
	@echo

hiarm64: hello.c
	@echo
	rm -f $@
	$(armcross)-gcc -static -s -x c $^ -o $@
	chmod +x $@
	@echo

uzprm64: uzpexec.arm
	rm -f $@
	$(armcross)-as $(armflags) -o $@.o $^
	$(armcross)-objcopy -O binary $@.o $@
	chmod +x $@ && du -b $@
	@echo

uzarm64: uzarm64.arm
	rm -f $@
	$(armcross)-as $(armflags) -o $@.o $^
	$(armcross)-objcopy -O binary $@.o $@
	chmod +x $@ && du -b $@
	@echo

_testa: hiarm64 hix86gz
	@echo ====== testing for ARM64 ======
	@echo
	@echo "RAF,TODO: argv[0] requires full path in Makefile"
	@echo "It might fail in Makefile, not in a login console"
	@echo
	strace $(armuqemu) \
    ./hix86gz $${WORLD:-nice} 2>&1 |\
        grep -E "execv|open\(|Hello" |\
            sed -e "s/, \[/,\n\t[/"
	@echo
	export WORLD=Wonderful && \
    $(armloadr) \
      ./hiarm64 $${WORLD:-nice}; printf "\tret: $$?\n"
	@echo
	export WORLD=Wonderful &&  \
    $(armloadr) \
      ./hix86gz $${WORLD:-nice}; printf "\tret: $$?\n"
	@echo
	{ cat uzprm64; gzip -9c hello.sh; } > hellz
	chmod +x hellz; export WORLD=Wonderful && \
	  ./hellz $${WORLD:-nice}; printf "\tret: $$?\n"
	@echo
	./uzprm64 <&- 2>&- | sed -e "s/^/    /" | grep robang74
	@echo
	@rm -f uzprm64
	@make JE_EXTRA=_DO_EXTRA uzprm64 >/dev/null 2>&1
	./uzprm64 <&- 2>&- | sed -e "s/^/    /" | grep 12345678
	@echo

testa:
	@echo
	@echo ====== compiling for ARM64 ======
	@echo
	rm -f uzprm64 hello hellz hiarm64 hlx86gz
	@echo
	@make _testa
	@echo

_testb: hiarm64 hlx86gz
	@echo ====== testing for ARM64 elf ======
	@echo
	@echo "RAF,TODO: argv[0] requires full path in Makefile"
	@echo "It might fail in Makefile, not in a login console"
	@echo
	strace $(armuqemu) \
    ./hlx86gz $${WORLD:-nice} 2>&1 |\
        grep -E "execv|open\(|Hello" |\
            sed -e "s/, \[/,\n\t[/"
	@echo
	export WORLD=Wonderful && \
    $(armloadr) \
      ./hiarm64 $${WORLD:-nice}; printf "\tret: $$?\n"
	@echo
	export WORLD=Wonderful &&  \
    $(armloadr) \
      ./hlx86gz $${WORLD:-nice}; printf "\tret: $$?\n"
	@echo
	./uzarm64 <&- 2>&- | sed -e "s/^/    /" | grep robang74
	@echo
	@rm -f uzarm64
	@make JE_EXTRA=_DO_EXTRA uzarm64 >/dev/null 2>&1
	./uzarm64 <&- 2>&- | sed -e "s/^/    /" | grep 12345678
	@echo

testb:
	@echo
	@echo ====== compiling for ARM64 elf ======
	@echo
	rm -f uzarm64 hello hiarm64 hlx86gz
	@echo
	@make _testb
	@echo

# -----------------------------------------------------------------------------
# Installation (DESTDIR-aware)
# -----------------------------------------------------------------------------
install: all
	install -d $(BINDIR)
	install -m 755 $(BINS) $(BINDIR)/
	install -d $(MANDIR)
	install -m 644 $(MANPAGES) $(MANDIR)/
	install -d $(SRCDIR)
	install -m 644 $(DEVFILES) $(SRCDIR)/
	@echo

uninstall:
	rm -f $(addprefix $(BINDIR)/, $(BINS))
	rm -f $(addprefix $(MANDIR)/, $(MANPAGES))
	rm -f $(DATADIR)/*
	rmdir $(DATADIR)/
	@echo

# -----------------------------------------------------------------------------
# Target: dist
# -----------------------------------------------------------------------------

# RAF, TODO: update the vesion everywhere in a smart way
uzpexec.spec: uzpexec.spec.tmpl
	cp -f $^ $@
	mkdir -p deb/
	@$(call git_changes_log,-1) > $(GITMPLOG)
	@$(call git_changes_log,)  >> $(GITMPLOG)
	@$(call git_relevant_log) $(GITMPLOG) | uniq >>$@
	@echo

$(GITMPLOG): uzpexec.spec

$(FILENME).tar.gz: rpm

dist: deb
	@echo
	@ls -al uzpexec-*.rpm uzpexec-*.t?z uzpexec-*.deb
	@echo

distclean: clean
	@echo ====== doing $@ ======
	@echo
	rm -f uzpexec-*.rpm uzpexec-*.deb zeroenv
	rm -f $(BINS) hello uzpexec-*.t?z sigsegv
	rm -f $(CLEN)
	@echo

# -----------------------------------------------------------------------------
# RPM package (.rpm)
# -----------------------------------------------------------------------------
rpm: distclean uzpexec.spec all
	rm -rf $(HOME)/rpmbuild
	for d in BUILD RPMS SOURCES SPECS SRPMS; do mkdir -p $(HOME)/rpmbuild/$$d; done
	mkdir -p $(HOME)/rpmbuild/BUILD/$(FILENME)
	cp -ar $(RPMFILES) $(HOME)/rpmbuild/BUILD/$(FILENME)/
	cd $(HOME)/rpmbuild/BUILD && tar czf ../SOURCES/$(FILENME).tar.gz $(FILENME)
	cp $(PKGNAME).spec $(HOME)/rpmbuild/SPECS/
	rpmbuild --nodeps -bb $(HOME)/rpmbuild/SPECS/$(PKGNAME).spec
	mv $(HOME)/rpmbuild/RPMS/*/$(FILENME)-*.rpm ./$(FILENME).rpm
	mv $(HOME)/rpmbuild/SOURCES/$(FILENME).tar.gz $(FILENME).tgz
	zcat $(FILENME).tgz | xz -9 - >$(FILENME).txz

# -----------------------------------------------------------------------------
# deb package (.deb)
# -----------------------------------------------------------------------------
deb: rpm  deb/control deb/changelog
	rm -rf deb/tmp
	mkdir -p deb/tmp/DEBIAN
	mkdir -p deb/tmp$(PREFIX)/bin
	mkdir -p deb/tmp$(PREFIX)/share/man/man1
	mkdir -p deb/tmp$(PREFIX)/share/uzpack/src
	install -m 755 $(BINS) deb/tmp$(PREFIX)/bin/
	install -m 644 $(MANPAGES) deb/tmp$(PREFIX)/share/man/man1/
	install -m 644 $(DEVFILES) deb/tmp$(PREFIX)/share/uzpack/src/
	install -m 644 deb/control deb/tmp/DEBIAN/control
	install -m 644 deb/changelog deb/tmp/DEBIAN/changelog
	gzip -9 -n deb/tmp$(PREFIX)/share/man/man1/*.1
	dpkg-deb --root-owner-group --build deb/tmp $(FILENME).deb
	rm -rf deb/tmp/

