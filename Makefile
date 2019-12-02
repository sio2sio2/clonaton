TEMPFILE := $(shell mktemp -d)
BASEDIR   = $(TEMPFILE)/var/lib/clonaton
VERSION   = 0.2.5-1

current_dir := $(shell pwd)

install:
	scripts/install.sh

uninstall:
	scripts/uninstall.sh

deb:
	mkdir -p $(BASEDIR) $(TEMPFILE)/usr/local/share/doc
	cp -a app scripts files drbl $(BASEDIR)
	cp -a docs $(TEMPFILE)/usr/local/share/doc/clonaton
	cp -a debian $(TEMPFILE)/DEBIAN
	find $(TEMPFILE) -name DEBIAN -prune -o -type f -print | xargs md5sum | sed -r 's:/tmp/[^/]+:.:' > $(TEMPFILE)/DEBIAN/md5sums
	sed -ri 's/^(Version: ).+/\1$(VERSION)/; $$a\Size: '`du -sb $(TEMPFILE) | awk '{print $$1}'` $(TEMPFILE)/DEBIAN/control
	dpkg -b $(TEMPFILE) $(current_dir)/../clonaton_$(VERSION)_all.deb
	rm -rf $(TEMPFILE)

pkg:
	tar -C .. -acvf ../clonaton_${VERSION}.tar.xz clonaton
