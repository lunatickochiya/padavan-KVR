#!/bin/sh

CUPS_CONFIG_DIR="/etc/storage/cups"
CUPS_DEFAULT_DIR="/etc_ro/cups"
CUPS_RUNTIME_DIR="/tmp/cups"

prepare_cups()
{
	lan_ip="$(nvram get lan_ipaddr)"
	[ -n "$lan_ip" ] || lan_ip="127.0.0.1"

	mkdir -p "$CUPS_CONFIG_DIR/ppd" "$CUPS_CONFIG_DIR/ssl"
	mkdir -p "$CUPS_RUNTIME_DIR/cache" "$CUPS_RUNTIME_DIR/log"
	mkdir -p "$CUPS_RUNTIME_DIR/spool/cups/tmp" "/var/run/cups/certs"

	if [ ! -s "$CUPS_CONFIG_DIR/cups-files.conf" ]; then
		cp "$CUPS_DEFAULT_DIR/cups-files.conf" "$CUPS_CONFIG_DIR/cups-files.conf"
	fi

	if [ ! -s "$CUPS_CONFIG_DIR/cupsd.conf" ]; then
		sed "s/@LAN_IP@/$lan_ip/g" "$CUPS_DEFAULT_DIR/cupsd.conf" > "$CUPS_CONFIG_DIR/cupsd.conf"
	else
		sed -i "s/^ServerAlias localhost .*/ServerAlias localhost $lan_ip/" "$CUPS_CONFIG_DIR/cupsd.conf"
	fi

	chown -R nobody:nogroup "$CUPS_RUNTIME_DIR/cache" "$CUPS_RUNTIME_DIR/spool"
	chmod 700 "$CUPS_CONFIG_DIR/ssl"
	chmod 710 "$CUPS_RUNTIME_DIR/spool/cups"
	chmod 1770 "$CUPS_RUNTIME_DIR/spool/cups/tmp"
}

start_cups()
{
	if pidof cupsd >/dev/null 2>&1; then
		return 0
	fi

	prepare_cups || return 1
	/usr/sbin/cupsd -c "$CUPS_CONFIG_DIR/cupsd.conf"
}

stop_cups()
{
	if ! pidof cupsd >/dev/null 2>&1; then
		return 0
	fi

	killall cupsd >/dev/null 2>&1
	wait_count=0
	while pidof cupsd >/dev/null 2>&1 && [ "$wait_count" -lt 5 ]; do
		sleep 1
		wait_count=$((wait_count + 1))
	done
}

case "$1" in
	start)
		start_cups
		;;
	stop)
		stop_cups
		;;
	restart)
		stop_cups
		start_cups
		;;
	*)
		echo "Usage: $0 {start|stop|restart}" >&2
		exit 1
		;;
esac
