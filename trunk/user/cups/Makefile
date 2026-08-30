SRC_VER = 2.4.19
SRC_NAME = cups-$(SRC_VER)
SRC_FILE = $(SRC_NAME)-source.tar.gz
SRC_URL = https://github.com/OpenPrinting/cups/releases/download/v$(SRC_VER)/$(SRC_FILE)
SRC_SHA256 = 820984b12a67f98705785aae2dd1347fe0ac097828001d4583ff64574aed6389

THISDIR = $(shell pwd)
PKGDIR = $(THISDIR)/install

CUPS_CFLAGS = $(CFLAGS) -ffunction-sections -fdata-sections
CUPS_LDFLAGS = $(LDFLAGS) -Wl,--gc-sections,-rpath-link=$(STAGEDIR)/lib

.PHONY: all clean configure download_test extract_test config_test package_test romfs

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)

download_test:
	( if ! printf '%s  %s\n' '$(SRC_SHA256)' '$(SRC_FILE)' | sha256sum -c - >/dev/null 2>&1; then \
		rm -f $(SRC_FILE); \
		wget -t5 --timeout=20 --no-check-certificate -O $(SRC_FILE) $(SRC_URL); \
		printf '%s  %s\n' '$(SRC_SHA256)' '$(SRC_FILE)' | sha256sum -c -; \
	fi )

extract_test: download_test
	( if [ ! -d $(SRC_NAME) ]; then \
		tar zxf $(SRC_FILE); \
	fi )

config_test: extract_test
	( if [ -f config_done ]; then \
		echo "the same configuration"; \
	else \
		$(MAKE) configure && touch config_done; \
	fi )

configure:
	( cd $(SRC_NAME); \
	PKG_CONFIG_PATH="$(STAGEDIR)/lib/pkgconfig" \
	PKG_CONFIG_LIBDIR="$(STAGEDIR)/lib/pkgconfig" \
	CFLAGS="$(CUPS_CFLAGS)" \
	CPPFLAGS="-I$(STAGEDIR)/include" \
	LDFLAGS="$(CUPS_LDFLAGS)" \
	LIBS="-L$(STAGEDIR)/lib" \
	./configure \
		--prefix=/usr \
		--libdir=/usr/lib \
		--sysconfdir=/etc/storage \
		--localstatedir=/tmp/cups \
		--with-cachedir=/tmp/cups/cache \
		--with-logdir=/tmp/cups/log \
		--with-rundir=/var/run/cups \
		--with-docdir=/usr/share/doc/cups \
		--with-printcap=/tmp/cups/printcap \
		--with-cups-user=nobody \
		--with-cups-group=nogroup \
		--with-system-groups=root \
		--with-languages="en zh_CN" \
		--with-max-log-size=256k \
		--with-access-log-level=actions \
		--with-dnssd=no \
		--with-tls=no \
		--with-ondemand=no \
		--disable-dbus \
		--disable-pam \
		--disable-gssapi \
		--disable-acl \
		--disable-tcp-wrappers \
		--disable-libpaper \
		--disable-unit-tests \
		--disable-default-shared \
		--disable-browsing \
		--enable-libusb \
		--enable-webif \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD); \
	)

package_test: all
	rm -rf $(PKGDIR)
	$(MAKE) -C $(SRC_NAME) install \
		DESTDIR=$(PKGDIR) \
		CUPS_USER=$(shell id -un) \
		CUPS_GROUP=$(shell id -gn) \
		CUPS_PRIMARY_SYSTEM_GROUP=$(shell id -gn) \
		INSTALL_BIN="install -c -m 755" \
		INSTALL_LIB="install -c -m 755"
	find $(PKGDIR)/usr -type f -perm /111 \
		-exec $(STRIP) --strip-unneeded {} + 2>/dev/null || true
	rm -rf $(PKGDIR)/usr/share/cups/ipptool
	rm -rf $(PKGDIR)/usr/share/cups/examples
	rm -f $(PKGDIR)/usr/bin/ippeveprinter $(PKGDIR)/usr/bin/ipptool
	rm -f $(PKGDIR)/usr/bin/ppdc $(PKGDIR)/usr/bin/ppdhtml
	rm -f $(PKGDIR)/usr/bin/ppdi $(PKGDIR)/usr/bin/ppdmerge
	rm -f $(PKGDIR)/usr/bin/ppdpo $(PKGDIR)/usr/bin/cupstestppd

clean:
	if [ -f $(SRC_NAME)/Makefile ]; then \
		$(MAKE) -C $(SRC_NAME) distclean; \
	fi
	rm -rf $(PKGDIR)
	rm -f config_done

romfs: package_test
	mkdir -p $(ROMFSDIR)/usr/bin $(ROMFSDIR)/usr/sbin $(ROMFSDIR)/usr/lib
	mkdir -p $(ROMFSDIR)/usr/share $(ROMFSDIR)/etc_ro/cups
	cp -fP $(PKGDIR)/usr/lib/libcups.so* $(ROMFSDIR)/usr/lib/
	cp -fP $(PKGDIR)/usr/lib/libcupsimage.so* $(ROMFSDIR)/usr/lib/
	cp -rf $(PKGDIR)/usr/lib/cups $(ROMFSDIR)/usr/lib/
	cp -rf $(PKGDIR)/usr/share/cups $(ROMFSDIR)/usr/share/
	cp -rf $(PKGDIR)/usr/share/doc $(ROMFSDIR)/usr/share/
	if [ -d $(PKGDIR)/usr/share/locale ]; then \
		cp -rf $(PKGDIR)/usr/share/locale $(ROMFSDIR)/usr/share/; \
	fi
	cp -f $(PKGDIR)/usr/bin/* $(ROMFSDIR)/usr/bin/
	cp -f $(PKGDIR)/usr/sbin/* $(ROMFSDIR)/usr/sbin/
	rm -f $(ROMFSDIR)/usr/bin/cups-config
	$(ROMFSINST) -p +x $(THISDIR)/cups.sh /usr/bin/cups.sh
	$(ROMFSINST) $(THISDIR)/cups-files.conf /etc_ro/cups/cups-files.conf
	$(ROMFSINST) $(THISDIR)/cupsd.conf /etc_ro/cups/cupsd.conf
