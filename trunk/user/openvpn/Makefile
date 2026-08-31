THISDIR = $(shell pwd)
SRC_NAME=openvpn-2.7.6
SRC_SHA256=10e24a9385f23cc38cc5cf448f3ca0769f939bc4cbecc4f4647d7e006e52db74

CFLAGS += -ffunction-sections -fdata-sections -fvisibility=hidden
LDFLAGS += -Wl,--gc-sections

all: extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		echo "$(SRC_SHA256)  $(SRC_NAME).tar.gz" | sha256sum -c - ; \
		tar -zxf $(SRC_NAME).tar.gz; \
		patch -d $(SRC_NAME) -p1 < $(SRC_NAME).patch ; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( cd $(SRC_NAME) ; \
	autoreconf -fi ; \
	GIT=false \
	IFCONFIG=/sbin/ifconfig \
	ROUTE=/sbin/route \
	NETSTAT=/bin/netstat \
	./configure \
		--prefix=/usr \
		--disable-debug \
		--disable-plugins \
		--disable-plugin-auth-pam \
		--disable-plugin-down-root \
		--disable-ofb-cfb \
		--disable-selinux \
		--disable-systemd \
		--disable-unit-tests \
		--disable-management \
		--disable-dco \
		--disable-lz4 \
		--disable-port-share \
		--enable-small \
		--enable-fragment \
		--enable-lzo \
		--with-crypto-library=openssl \
		--with-sysroot=$(STAGEDIR) \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD) ; \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME) distclean ; \
	fi ; \
	rm -f config_done

romfs:
	$(ROMFSINST) $(SRC_NAME)/src/openvpn/openvpn /usr/sbin/openvpn
	$(ROMFSINST) -p +x $(THISDIR)/openvpn-cert.sh /usr/bin/openvpn-cert.sh
