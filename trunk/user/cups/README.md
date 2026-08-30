# Padavan CUPS plugin

This optional package adds CUPS 2.4.19 with the USB, IPP, JetDirect/socket,
and LPR backends. It also includes the CUPS web administration interface and
the built-in raster filters.

## Build

Add the following option to the router template in `trunk/configs/templates`:

```text
CONFIG_FIRMWARE_INCLUDE_CUPS=y
```

USB support and the `usblp` kernel module must also be enabled for a local USB
printer. CUPS is intentionally not enabled in every model template because it
adds several megabytes to the uncompressed firmware image.

## Use

After flashing the image, open **USB Application > Printer** and enable CUPS.
The same page contains a button for the administration interface on TCP port
631. Log in with the router administrator account when CUPS asks for
credentials.

Printer queues, PPD files, and local configuration are stored persistently in
`/etc/storage/cups`. Jobs, caches, and logs are stored under `/tmp/cups` so
print data does not consume flash storage. Enabling CUPS disables the legacy
RAW, LPRng, and u2ec printer services to prevent concurrent device access.

The package also includes the brlaser Brother laser driver. Its 34 model PPD
files are generated from `brlaser.drv` with the host `ppdc` tool during the
build and installed under `/usr/share/ppd/Brother`.
