SMARTDNS_VERSION := 48.4
SRC_NAME := smartdns-Release$(SMARTDNS_VERSION)
SRC_SHA256 := b07abba99e921f262ba47588e12f5b36dd849f79c0145542440eb6b7eed80553
PATCH_NAME := 001-padavan-uclibc.patch
THISDIR := $(shell pwd)

all: extract_test config_test
	$(MAKE) -C $(SRC_NAME)/src \
		WITH_ZLIB=0 \
		VER=$(SMARTDNS_VERSION) \
		NO_GIT_VER=1 \
		USE_ATOMIC=1 \
		EXTRA_LDFLAGS="-Wl,-Bstatic -latomic -Wl,-Bdynamic"

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		echo "$(SRC_SHA256)  $(SRC_NAME).tar.gz" | sha256sum -c - && \
		tar zxf $(SRC_NAME).tar.gz && \
		patch -d $(SRC_NAME) -p1 -i ../$(PATCH_NAME) ; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		touch config_done; \
	fi )

clean:
	if [ -f $(SRC_NAME)/src/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME)/src clean ; \
	fi ; \
	rm -f config_done

romfs:
	$(STRIP) $(THISDIR)/$(SRC_NAME)/src/smartdns
	$(ROMFSINST) -p +x $(THISDIR)/$(SRC_NAME)/src/smartdns /usr/bin/smartdns
	$(ROMFSINST) -p +x $(THISDIR)/smartdns.sh /usr/bin/smartdns.sh
	$(ROMFSINST) /etc_ro/smartdns_address.conf
	$(ROMFSINST) /etc_ro/smartdns_blacklist-ip.conf
	$(ROMFSINST) /etc_ro/smartdns_custom.conf
	$(ROMFSINST) /etc_ro/smartdns_whitelist-ip.conf
