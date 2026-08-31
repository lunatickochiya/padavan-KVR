SRC_VER = 2.4.19
SRC_NAME = cups-$(SRC_VER)
SRC_FILE = $(SRC_NAME)-source.tar.gz
SRC_URL = https://github.com/OpenPrinting/cups/releases/download/v$(SRC_VER)/$(SRC_FILE)
SRC_SHA256 = 820984b12a67f98705785aae2dd1347fe0ac097828001d4583ff64574aed6389

BRLASER_VER = 3
BRLASER_NAME = brlaser-$(BRLASER_VER)
BRLASER_FILE = $(BRLASER_NAME).tar.gz
BRLASER_SHA256 = 5f6489599ac9cd7a397ee52608f10febead8ba31f871bd0a33704d61775e0e75
BRLASER_PATCH = brlaser-uclibc.patch
BRLASER_BUILD = $(BRLASER_NAME)/build
BRLASER_PPD = $(BRLASER_BUILD)/ppd

THISDIR = $(shell pwd)
PKGDIR = $(THISDIR)/install

CUPS_CFLAGS = $(CFLAGS) -I$(STAGEDIR)/include/libusb-1.0 -ffunction-sections -fdata-sections
CUPS_LDFLAGS = $(LDFLAGS) -Wl,--gc-sections,-rpath-link=$(STAGEDIR)/lib
BRLASER_CC = $(word 1,$(CC))
BRLASER_CXX = $(word 1,$(CXX))
BRLASER_CFLAGS = $(CFLAGS) $(CPUFLAGS)

.PHONY: all clean configure download_test extract_test config_test package_test package_cups package_brlaser romfs

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME) \
		CFLAGS="$(CUPS_CFLAGS)" \
		CPPFLAGS="-I$(STAGEDIR)/include" \
		LDFLAGS="$(CUPS_LDFLAGS)" \
		LIBS="-L$(STAGEDIR)/lib -liconv -lz -lpthread"
	$(MAKE) package_cups
	$(MAKE) package_brlaser

download_test:
	( if ! printf '%s  %s\n' '$(SRC_SHA256)' '$(SRC_FILE)' | sha256sum -c - >/dev/null 2>&1; then \
		rm -f $(SRC_FILE); \
		wget -t5 --timeout=20 --no-check-certificate -O $(SRC_FILE) $(SRC_URL); \
		printf '%s  %s\n' '$(SRC_SHA256)' '$(SRC_FILE)' | sha256sum -c -; \
	fi )

extract_test: download_test
	( if [ ! -d $(SRC_NAME) ]; then \
		tar zxf $(SRC_FILE); \
	fi; \
	if [ ! -d $(BRLASER_NAME) ]; then \
		echo "$(BRLASER_SHA256)  $(BRLASER_FILE)" | sha256sum -c - && \
		tar zxf $(BRLASER_FILE) && \
		patch -d $(BRLASER_NAME) -p1 -i ../$(BRLASER_PATCH); \
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
	LIBS="-L$(STAGEDIR)/lib -liconv -lz -lpthread" \
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

package_cups:
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

package_brlaser:
	rm -rf $(BRLASER_BUILD)
	cmake -S $(BRLASER_NAME) -B $(BRLASER_BUILD) \
		-DCMAKE_SYSTEM_NAME=Linux \
		-DCMAKE_C_COMPILER=$(BRLASER_CC) \
		-DCMAKE_CXX_COMPILER=$(BRLASER_CXX) \
		-DCMAKE_AR=$(AR) \
		-DCMAKE_RANLIB=$(RANLIB) \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCOMPILER_SUPPORT__fstack_protector_strong=FALSE \
		-DCMAKE_C_FLAGS="$(BRLASER_CFLAGS)" \
		-DCMAKE_CXX_FLAGS="$(BRLASER_CFLAGS) -static-libstdc++ -static-libgcc" \
		-DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS) $(CPUFLAGS) -Wl,--gc-sections,-rpath-link=$(STAGEDIR)/lib -static-libstdc++ -static-libgcc -L$(STAGEDIR)/lib" \
		-DCUPS_DATA_DIR=/usr/share/cups \
		-DCUPS_SERVER_BIN=/usr/lib/cups \
		-DCUPS_CONFIG=$(PKGDIR)/usr/bin/cups-config \
		-DCUPS_CFLAGS=-I$(PKGDIR)/usr/include \
		-DCUPS_LDFLAGS="-L$(PKGDIR)/usr/lib -L$(STAGEDIR)/lib" \
		-DCUPS_LIBS="-L$(PKGDIR)/usr/lib;-L$(STAGEDIR)/lib;-lcupsimage;-lcups;-liconv;-lz;-lpthread"
	$(MAKE) -C $(BRLASER_BUILD) rastertobrlaser
	$(STRIP) --strip-unneeded $(BRLASER_BUILD)/rastertobrlaser 2>/dev/null || true
	mkdir -p $(BRLASER_PPD)
	command -v ppdc >/dev/null 2>&1 || { echo "ppdc is required to generate brlaser PPD files" >&2; exit 1; }
	ppdc -I $(PKGDIR)/usr/share/cups/ppdc -d $(BRLASER_PPD) $(BRLASER_BUILD)/brlaser.drv
	test -n "$$(find $(BRLASER_PPD) -type f -name '*.ppd' -print -quit)"
	mkdir -p $(PKGDIR)/usr/lib/cups/filter $(PKGDIR)/usr/share/cups/drv $(PKGDIR)/usr/share/ppd/Brother
	install -m 0755 $(BRLASER_BUILD)/rastertobrlaser $(PKGDIR)/usr/lib/cups/filter/rastertobrlaser
	install -m 0644 $(BRLASER_BUILD)/brlaser.drv $(PKGDIR)/usr/share/cups/drv/brlaser.drv
	cp -f $(BRLASER_PPD)/*.ppd $(PKGDIR)/usr/share/ppd/Brother/
	rm -f $(PKGDIR)/usr/bin/cups-config

package_test: all
	test -x $(PKGDIR)/usr/lib/cups/filter/rastertobrlaser
	test -n "$$(find $(PKGDIR)/usr/share/ppd/Brother -type f -name '*.ppd' -print -quit)"

clean:
	if [ -f $(SRC_NAME)/Makefile ]; then \
		$(MAKE) -C $(SRC_NAME) distclean; \
	fi
	rm -rf $(PKGDIR)
	rm -rf $(BRLASER_BUILD)
	rm -f config_done

romfs: package_test
	mkdir -p $(ROMFSDIR)/usr/bin $(ROMFSDIR)/usr/sbin $(ROMFSDIR)/usr/lib
	mkdir -p $(ROMFSDIR)/usr/share $(ROMFSDIR)/etc_ro/cups
	cp -fP $(PKGDIR)/usr/lib/libcups.so* $(ROMFSDIR)/usr/lib/
	cp -fP $(PKGDIR)/usr/lib/libcupsimage.so* $(ROMFSDIR)/usr/lib/
	cp -rf $(PKGDIR)/usr/lib/cups $(ROMFSDIR)/usr/lib/
	cp -rf $(PKGDIR)/usr/share/cups $(ROMFSDIR)/usr/share/
	if [ -d $(PKGDIR)/usr/share/ppd ]; then \
		cp -rf $(PKGDIR)/usr/share/ppd $(ROMFSDIR)/usr/share/; \
	fi
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
