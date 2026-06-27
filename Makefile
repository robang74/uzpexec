#
# (c) 2026 Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2 license
#
################################################################################

# -----------------------------------------------------------------------------
# Standard directories
# -----------------------------------------------------------------------------
PREFIX  ?= /usr/local
DESTDIR ?=
BINDIR   = $(DESTDIR)$(PREFIX)/bin
MANDIR   = $(DESTDIR)$(PREFIX)/share/man/man1
DATADIR  = $(DESTDIR)$(PREFIX)/share/uzpack
SRCDIR   = $(DATADIR)/src

# -----------------------------------------------------------------------------
# Package metadata
# -----------------------------------------------------------------------------
PKGNAME    = uzpexec
VERSION    = 0.84
ARCH       = $(shell dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null || uname -m)
MAINTAINER = Roberto A. Foglietta <roberto.foglietta@gmail.com>

# -----------------------------------------------------------------------------
# Files
# -----------------------------------------------------------------------------
BINS     = uzpexec uzpack gzcmd.gz.sh
MANPAGES = uzpack.1 uzpexec.1
DEVFILES = uzpack.sh uzpexec.asm gzcmd.sh hello.c tests.sh README.md Makefile
RPMFILES = $(BINS) $(MANPAGES) $(DEVFILES) uzpexec.spec.tmpl

# -----------------------------------------------------------------------------
# Build targets
# -----------------------------------------------------------------------------
.PHONY: all blkln tests clean install uninstall deb rpm

all: $(BINS)

blkln:
	@echo

ZDDCMD := dd if=hello.gz.sh skip=1 | zcat

gzcmd.gz.sh: gzcmd.sh
	@echo ====== $^ self-compressing ======
	@echo
	sh $^ $^
	du -b $@
	@echo

uzpexec: uzpexec.asm
	@echo ====== compile $^ ======
	@echo
	nasm -O2 -f bin $^ -o $@
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

uzpack: uzpexec uzpack.sh
	@echo ====== produce $@ ======
	@echo
	sh uzpack.sh -u uzpexec
	@rm -f uzpack
	sh uzpack.sh uzpack.sh uzpack
	du -b $@
	@echo

# RAF, TODO: update the vesion everywhere in a smart way
uzpexec.spec: uzpexec.spec.tmpl
	cp -f $^ $@
	mkdir -p deb/
	@git log --abbrev-commit --date=short --format=format:'+ %h - %ad - %s %d' | grep --color=never tag -1 > deb/changes.log
	@git log --abbrev-commit --date=short --format=format:'+ %h - %ad - %s %d' | grep --color=never tag >> deb/changes.log
	grep -e '^\+' deb/changes.log | uniq | sed -e 's/ *.HEAD -. .*//' -e 's/ *.tag: .*//' >>$@

clean: blkln
	rm -rf deb/tmp uzpexec.spec.tmp uzpexec.spec
	rm -f tests.res uzpack.uzp uzpexec.uzp
	rm -f hello.gz.sh ls.elf ls.gz.elf lz
	@echo

distclean: clean
	rm -f uzpexec-*.rpm $(BINS) hello
	@echo

tests: blkln distclean hello $(BINS)
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

uninstall:
	rm -f $(addprefix $(BINDIR)/, $(BINS))
	rm -f $(addprefix $(MANDIR)/, $(MANPAGES))
	rm -rf $(DATADIR)

# -----------------------------------------------------------------------------
# RPM package (.rpm)
# -----------------------------------------------------------------------------
rpm: distclean uzpexec.spec all
	rm -rf $(HOME)/rpmbuild
	for d in BUILD RPMS SOURCES SPECS SRPMS; do mkdir -p $(HOME)/rpmbuild/$$d; done
	mkdir -p $(HOME)/rpmbuild/BUILD/$(PKGNAME)-$(VERSION)
	cp -ar $(RPMFILES) $(HOME)/rpmbuild/BUILD/$(PKGNAME)-$(VERSION)/
	cd $(HOME)/rpmbuild/BUILD && tar czf ../SOURCES/$(PKGNAME)-$(VERSION).tar.gz $(PKGNAME)-$(VERSION)
	cp $(PKGNAME).spec $(HOME)/rpmbuild/SPECS/	
	rpmbuild --nodeps -bb $(HOME)/rpmbuild/SPECS/$(PKGNAME).spec
	cp $(HOME)/rpmbuild/RPMS/*/$(PKGNAME)-$(VERSION)-*.rpm ./

