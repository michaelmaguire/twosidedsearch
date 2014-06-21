TARGET=debian/tmp
VERSION=$(shell grep Version: debian/control | sed 's/Version: //')
DEB=speedy-notifier_$(VERSION)_all.deb

# TODO use proper source package with rules rather than this direct
# binary package construction

build:
	mkdir -p $(TARGET)/usr/bin
	mkdir -p $(TARGET)/etc/init.d
	mkdir -p $(TARGET)/usr/share/doc/speedy-notifier
	mkdir -p $(TARGET)/DEBIAN
	cp speedy_notifier $(TARGET)/usr/bin/
	cp debian/init.d $(TARGET)/etc/init.d/speedy_notifier
	cp debian/speedy_notifier.conf $(TARGET)/etc/
	cp debian/copyright $(TARGET)/usr/share/doc/speedy-notifier/
	gzip -9 < debian/changelog > $(TARGET)/usr/share/doc/speedy-notifier/changelog.gz
	cp debian/control debian/conffiles debian/postinst debian/postrm $(TARGET)/DEBIAN/
	sed 's/@VERSION/$(VERSION)/' < debian/control > $(TARGET)/DEBIAN/control

package:
	fakeroot dpkg-deb --build $(TARGET) $(DEB)

lint:
	lintian $(DEB)

clean:
	rm -fr $(TARGET)