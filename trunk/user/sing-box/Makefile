SING_BOX_VERSION := 1.14.1
SING_BOX_URL := https://codeload.github.com/SagerNet/sing-box/tar.gz/v$(SING_BOX_VERSION)
SING_BOX_SHA256 := 1ea41f7d06b0017fe3d3ba7ee30959048aa0ddde31cb0165dab9257edf673321
SING_BOX_DIR := sing-box/sing-box-$(SING_BOX_VERSION)

THISDIR = $(shell pwd)

all: download build_extract build

download:
	( if [ ! -f $(THISDIR)/sing-box-$(SING_BOX_VERSION).tar.gz ]; then \
	curl --create-dirs -L $(SING_BOX_URL) -o $(THISDIR)/sing-box-$(SING_BOX_VERSION).tar.gz ; \
	fi; \
	echo "$(SING_BOX_SHA256)  $(THISDIR)/sing-box-$(SING_BOX_VERSION).tar.gz" | sha256sum -c - ; \
	)

build_extract:
	mkdir -p $(THISDIR)/sing-box
	mkdir -p $(THISDIR)/bin
	( if [ ! -d $(THISDIR)/$(SING_BOX_DIR) ]; then \
	rm -rf $(THISDIR)/sing-box/* ; \
	tar zxf $(THISDIR)/sing-box-$(SING_BOX_VERSION).tar.gz -C $(THISDIR)/sing-box ; \
	fi )

build:
	( cd $(THISDIR)/$(SING_BOX_DIR); \
	GOOS=linux GOARCH=mipsle CGO_ENABLED=0 GOMIPS=softfloat go build \
		-tags "with_quic,with_utls" \
		-o $(THISDIR)/bin/sing-box -trimpath \
		-ldflags "-s -w -buildid= -X github.com/sagernet/sing-box/constant.Version=$(SING_BOX_VERSION)" \
		./cmd/sing-box; \
	upx --lzma --best $(THISDIR)/bin/sing-box; \
	)

clean:
	rm -rf $(THISDIR)/sing-box
	rm -rf $(THISDIR)/bin

romfs:
	$(ROMFSINST) -p +x $(THISDIR)/bin/sing-box /usr/bin/sing-box

.EXPORT_ALL_VARIABLES:
.PHONY: all romfs clean
