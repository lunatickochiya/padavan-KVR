#!/bin/sh

PASSFILE="/etc/openvpn/server/psw-file"
TIME_STAMP=$(date "+%Y-%m-%d %T")

if [ ! -r "$PASSFILE" ] || [ -z "$username" ] || [ -z "$password" ]; then
	logger -t openvpn-auth "$TIME_STAMP authentication failed"
	exit 1
fi

awk '
	BEGIN {
		user = ENVIRON["username"]
		pass = ENVIRON["password"]
		matched = 0
	}
	/^[;#]/ { next }
	$1 == user && $2 == pass {
		matched = 1
		exit
	}
	END { exit matched ? 0 : 1 }
' "$PASSFILE"
result=$?

if [ "$result" -eq 0 ]; then
	logger -t openvpn-auth "$TIME_STAMP authentication accepted"
else
	logger -t openvpn-auth "$TIME_STAMP authentication failed"
fi

exit "$result"
