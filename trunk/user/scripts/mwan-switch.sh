#!/bin/sh

APP="mwan-switch"
WAN2_IF="eth2.3"
WAN2_PPP_IF="ppp1"
LAN2_IF="eth2.4"
LAN2_BR="br1"
ROUTE_TABLE="200"
RULE_PRIORITY="20000"
UDHCPC_PID="/var/run/udhcpc_mwan2.pid"
PPPD_PID="/var/run/ppp-mwan2.pid"
PPPD_IF_PID="/var/run/ppp1.pid"
PPPD_OPTIONS="/tmp/ppp/options.mwan2"
PPPD_IPUP="/tmp/ppp/mwan2-ip-up"
PPPD_IPDOWN="/tmp/ppp/mwan2-ip-down"

log()
{
	logger -t "$APP" "$*"
}

nvget()
{
	nvram get "$1" 2>/dev/null
}

valid_ipv4()
{
	local old_ifs octet
	old_ifs="$IFS"
	IFS='.'
	set -- $1
	IFS="$old_ifs"
	[ "$#" -eq 4 ] || return 1
	for octet in "$@"; do
		case "$octet" in
			''|*[!0-9]*) return 1 ;;
		esac
		[ "$octet" -le 255 ] || return 1
	done
	return 0
}

valid_lan_gateway()
{
	local host
	valid_ipv4 "$1" || return 1
	host="${1##*.}"
	[ "$host" -gt 0 ] && [ "$host" -lt 255 ]
}

valid_netmask()
{
	valid_ipv4 "$1" || return 1
	echo "$1" | awk -F. '
		BEGIN { valid = 1; ended = 0 }
		{
			for (i = 1; i <= 4; i++) {
				if ($i != 255 && $i != 254 && $i != 252 && $i != 248 &&
				    $i != 240 && $i != 224 && $i != 192 && $i != 128 && $i != 0)
					valid = 0
				if (ended && $i != 0)
					valid = 0
				if ($i != 255)
					ended = 1
			}
			if ($1 == 0 && $2 == 0 && $3 == 0 && $4 == 0)
				valid = 0
		}
		END { exit(valid ? 0 : 1) }'
}

subnets_overlap()
{
	local ip1="$1" mask1="$2" ip2="$3" mask2="$4"
	valid_ipv4 "$ip1" && valid_netmask "$mask1" &&
	valid_ipv4 "$ip2" && valid_netmask "$mask2" || return 1
	awk -v ip1="$ip1" -v mask1="$mask1" -v ip2="$ip2" -v mask2="$mask2" '
		BEGIN {
			split(ip1, a, "."); split(mask1, ma, ".")
			split(ip2, b, "."); split(mask2, mb, ".")
			for (i = 1; i <= 4; i++) {
				m = (ma[i] < mb[i]) ? ma[i] : mb[i]
				block = 256 - m
				if (block == 0) block = 1
				if (int(a[i] / block) != int(b[i] / block))
					exit 1
			}
			exit 0
		}'
}

read_config()
{
	ENABLED="$(nvget mwan_enable)"
	WAN2_PROTO="$(nvget mwan_proto)"
	WAN2_PPPOE_USER="$(nvget mwan_pppoe_username)"
	WAN2_PPPOE_PASS="$(nvget mwan_pppoe_passwd)"
	WAN2_IP="$(nvget mwan_ipaddr)"
	WAN2_MASK="$(nvget mwan_netmask)"
	WAN2_GW="$(nvget mwan_gateway)"
	LAN2_IP="$(nvget mwan_lan_ip)"
	LAN4_ROUTE="$(nvget mwan_lan4)"
	WIFI24_ROUTE="$(nvget mwan_wifi24)"
	WIFI5_ROUTE="$(nvget mwan_wifi5)"

	case "$WAN2_PROTO" in
		dhcp|static|pppoe) ;;
		*) WAN2_PROTO="dhcp" ;;
	esac
	valid_lan_gateway "$LAN2_IP" || LAN2_IP="192.168.77.1"
	LAN2_PREFIX="${LAN2_IP%.*}"
	LAN2_NET="${LAN2_PREFIX}.0/24"
	[ "$LAN4_ROUTE" = "wan2" ] || LAN4_ROUTE="wan1"
	[ "$WIFI24_ROUTE" = "wan2" ] || WIFI24_ROUTE="wan1"
	[ "$WIFI5_ROUTE" = "wan2" ] || WIFI5_ROUTE="wan1"
}

wan2_out_if()
{
	if [ "$WAN2_PROTO" = "pppoe" ]; then
		echo "$WAN2_PPP_IF"
	else
		echo "$WAN2_IF"
	fi
}

ppp_escape()
{
	printf '%s' "$1" | tr '\r\n' '  ' | sed "s/[\\\\']/\\\\&/g"
}

write_pppoe_options()
{
	local username password
	username="$(ppp_escape "$WAN2_PPPOE_USER")"
	password="$(ppp_escape "$WAN2_PPPOE_PASS")"
	mkdir -p /tmp/ppp || return 1
	ln -sf /usr/bin/mwan-switch.sh "$PPPD_IPUP" || return 1
	ln -sf /usr/bin/mwan-switch.sh "$PPPD_IPDOWN" || return 1
	{
		echo "noauth"
		printf "user '%s'\n" "$username"
		printf "password '%s'\n" "$password"
		echo "refuse-eap"
		echo "plugin rp-pppoe.so"
		echo "nic-$WAN2_IF"
		echo "persist"
		echo "maxfail 0"
		echo "holdoff 10"
		echo "ipcp-accept-remote ipcp-accept-local"
		echo "noipdefault"
		echo "nodefaultroute"
		echo "usepeerdns"
		echo "mtu 1492"
		echo "mru 1492"
		echo "default-asyncmap"
		echo "nopcomp noaccomp"
		echo "novj nobsdcomp nodeflate"
		echo "nomppe nomppc"
		echo "lcp-echo-interval 20"
		echo "lcp-echo-failure 6"
		echo "unit 1"
		echo "linkname mwan2"
		echo "ipparam mwan2"
		echo "ip-up-script $PPPD_IPUP"
		echo "ip-down-script $PPPD_IPDOWN"
		echo "ktune"
	} > "$PPPD_OPTIONS" || return 1
	chmod 0600 "$PPPD_OPTIONS"
}

kill_pidfile()
{
	local pid_file="$1" pid
	[ -s "$pid_file" ] || return 0
	pid="$(sed -n '1p' "$pid_file")"
	case "$pid" in
		''|*[!0-9]*) ;;
		*) kill "$pid" 2>/dev/null ;;
	esac
	rm -f "$pid_file"
}

clear_policy_rule()
{
	ip rule del priority "$RULE_PRIORITY" 2>/dev/null
	ip route flush table "$ROUTE_TABLE" 2>/dev/null
	ip route flush cache 2>/dev/null
}

add_local_routes()
{
	local main_lan_net
	ip route add table "$ROUTE_TABLE" "$LAN2_NET" dev "$LAN2_BR" src "$LAN2_IP"
	main_lan_net="$(ip route show dev br0 scope link 2>/dev/null | awk 'NR == 1 {print $1}')"
	case "$main_lan_net" in
		*/*) ip route add table "$ROUTE_TABLE" "$main_lan_net" dev br0 2>/dev/null ;;
	esac
}

install_policy_rule()
{
	clear_policy_rule
	ip rule add priority "$RULE_PRIORITY" from "$LAN2_NET" table "$ROUTE_TABLE" || return 1
	add_local_routes
	ip route flush cache 2>/dev/null
}

install_wan2_route()
{
	local gateway="$1" link_net
	valid_ipv4 "$gateway" || return 1

	ip route flush table "$ROUTE_TABLE" 2>/dev/null
	add_local_routes
	link_net="$(ip route show dev "$WAN2_IF" scope link 2>/dev/null | awk 'NR == 1 {print $1}')"
	case "$link_net" in
		*/*) ip route add table "$ROUTE_TABLE" "$link_net" dev "$WAN2_IF" 2>/dev/null ;;
	esac
	ip route add table "$ROUTE_TABLE" default via "$gateway" dev "$WAN2_IF" || return 1
	ip route flush cache 2>/dev/null
	return 0
}

install_wan2_ppp_route()
{
	local local_ip="$1" remote_ip="$2"
	valid_ipv4 "$local_ip" && valid_ipv4 "$remote_ip" || return 1

	ip route flush table "$ROUTE_TABLE" 2>/dev/null
	add_local_routes
	ip route add table "$ROUTE_TABLE" "$remote_ip/32" dev "$WAN2_PPP_IF" src "$local_ip" 2>/dev/null
	ip route add table "$ROUTE_TABLE" default via "$remote_ip" dev "$WAN2_PPP_IF" || return 1
	ip route flush cache 2>/dev/null
	return 0
}

apply_firewall()
{
	local out_if
	read_config
	[ "$ENABLED" = "1" ] || return 0
	[ -d "/sys/class/net/$LAN2_BR" ] || return 0
	out_if="$(wan2_out_if)"

	iptables -t nat -N MWAN2_POST 2>/dev/null || iptables -t nat -F MWAN2_POST
	iptables -t nat -D POSTROUTING -j MWAN2_POST 2>/dev/null
	iptables -t nat -I POSTROUTING 1 -j MWAN2_POST
	iptables -t nat -A MWAN2_POST -s "$LAN2_NET" -o "$out_if" -j MASQUERADE

	iptables -N MWAN2_INPUT 2>/dev/null || iptables -F MWAN2_INPUT
	iptables -D INPUT -j MWAN2_INPUT 2>/dev/null
	iptables -I INPUT 1 -j MWAN2_INPUT
	iptables -A MWAN2_INPUT -i "$LAN2_BR" -j ACCEPT

	iptables -N MWAN2_FORWARD 2>/dev/null || iptables -F MWAN2_FORWARD
	iptables -D FORWARD -j MWAN2_FORWARD 2>/dev/null
	iptables -I FORWARD 1 -j MWAN2_FORWARD
	iptables -A MWAN2_FORWARD -i "$LAN2_BR" -o "$out_if" -j ACCEPT
	iptables -A MWAN2_FORWARD -i "$out_if" -o "$LAN2_BR" -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -A MWAN2_FORWARD -i "$LAN2_BR" -o br0 -j ACCEPT
	iptables -A MWAN2_FORWARD -i br0 -o "$LAN2_BR" -j ACCEPT
}

move_wifi()
{
	local ifname="$1" route="$2" bridge="br0"
	[ -d "/sys/class/net/$ifname" ] || return 0
	[ "$route" = "wan2" ] && bridge="$LAN2_BR"
	brctl delif br0 "$ifname" 2>/dev/null
	brctl delif "$LAN2_BR" "$ifname" 2>/dev/null
	brctl addif "$bridge" "$ifname" 2>/dev/null || log "failed to add $ifname to $bridge"
}

configure_switch()
{
	local lan_member=16396 lan_untag=12 vlan_mask

	if [ "$LAN4_ROUTE" = "wan1" ]; then
		lan_member=$((lan_member + 16))
		lan_untag=$((lan_untag + 16))
	fi
	vlan_mask=$((lan_untag * 65536 + lan_member))

	# VLAN 1: LAN2/LAN3 and optionally LAN4, with a tagged CPU port.
	mtk_esw 63 "$(printf '0x%08x' "$vlan_mask")" 0x00010001 || return 1
	# VLAN 3: physical LAN1 is the dedicated WAN2 uplink.
	mtk_esw 63 0x00024002 0x00030003 || return 1
	if [ "$LAN4_ROUTE" = "wan2" ]; then
		# VLAN 4: physical LAN4 is attached to br1.
		mtk_esw 63 0x00104010 0x00040004 || return 1
	fi
	mtk_esw 43 >/dev/null 2>&1
}

create_vlan_interface()
{
	local vid="$1" ifname="eth2.$1"
	[ -d "/sys/class/net/$ifname" ] || vconfig add eth2 "$vid" >/dev/null 2>&1
	[ -d "/sys/class/net/$ifname" ] || return 1
	ifconfig "$ifname" up
}

start_service()
{
	local main_lan_ip main_lan_mask
	read_config
	[ "$ENABLED" = "1" ] || return 0
	[ "$(nvget sw_mode)" != "3" ] || {
		log "dual WAN is unavailable in access point mode"
		return 1
	}

	main_lan_ip="$(nvget lan_ipaddr)"
	main_lan_mask="$(nvget lan_netmask)"
	if subnets_overlap "$LAN2_IP" 255.255.255.0 "$main_lan_ip" "$main_lan_mask"; then
		log "WAN2 client subnet conflicts with the primary LAN"
		return 1
	fi
	if [ "$WAN2_PROTO" = "static" ]; then
		valid_ipv4 "$WAN2_IP" && valid_netmask "$WAN2_MASK" && valid_ipv4 "$WAN2_GW" || {
			log "invalid static WAN2 address"
			return 1
		}
		subnets_overlap "$WAN2_IP" "$WAN2_MASK" "$WAN2_GW" "$WAN2_MASK" || {
			log "static WAN2 gateway is outside its subnet"
			return 1
		}
		if subnets_overlap "$WAN2_IP" "$WAN2_MASK" "$LAN2_IP" 255.255.255.0 ||
		   subnets_overlap "$WAN2_IP" "$WAN2_MASK" "$main_lan_ip" "$main_lan_mask"; then
			log "static WAN2 subnet conflicts with a client LAN"
			return 1
		fi
	elif [ "$WAN2_PROTO" = "pppoe" ]; then
		[ -n "$WAN2_PPPOE_USER" ] && [ -n "$WAN2_PPPOE_PASS" ] || {
			log "WAN2 PPPoE username or password is empty"
			nvram settmp "mwan_wan2_state_t=config_error"
			return 1
		}
	fi

	configure_switch || {
		log "failed to configure MT7530 VLANs"
		return 1
	}
	create_vlan_interface 3 || return 1
	if [ "$LAN4_ROUTE" = "wan2" ]; then
		create_vlan_interface 4 || return 1
	fi

	[ -d "/sys/class/net/$LAN2_BR" ] || brctl addbr "$LAN2_BR"
	brctl stp "$LAN2_BR" off
	brctl setfd "$LAN2_BR" 2
	ifconfig "$LAN2_BR" "$LAN2_IP" netmask 255.255.255.0 up
	if [ "$LAN4_ROUTE" = "wan2" ]; then
		brctl delif br0 "$LAN2_IF" 2>/dev/null
		brctl addif "$LAN2_BR" "$LAN2_IF" 2>/dev/null || {
			log "failed to attach physical LAN4 to $LAN2_BR"
			return 1
		}
	fi
	move_wifi rax0 "$WIFI24_ROUTE"
	move_wifi ra0 "$WIFI5_ROUTE"

	echo 0 > "/proc/sys/net/ipv4/conf/$WAN2_IF/rp_filter"
	echo 0 > "/proc/sys/net/ipv4/conf/$LAN2_BR/rp_filter"
	install_policy_rule || {
		log "failed to install WAN2 policy rule"
		return 1
	}
	apply_firewall

	kill_pidfile "$UDHCPC_PID"
	kill_pidfile "$PPPD_PID"
	rm -f "$PPPD_IF_PID"
	if [ "$WAN2_PROTO" = "static" ]; then
		ifconfig "$WAN2_IF" "$WAN2_IP" netmask "$WAN2_MASK" up
		install_wan2_route "$WAN2_GW" || {
			log "failed to install static WAN2 route"
			nvram settmp "mwan_wan2_state_t=route_error"
			return 1
		}
		nvram settmp "mwan_wan2_ip_t=$WAN2_IP"
		nvram settmp "mwan_wan2_gateway_t=$WAN2_GW"
		nvram settmp "mwan_wan2_state_t=connected"
	elif [ "$WAN2_PROTO" = "pppoe" ]; then
		ifconfig "$WAN2_IF" 0.0.0.0 up
		write_pppoe_options || {
			log "failed to write WAN2 PPPoE options"
			nvram settmp "mwan_wan2_state_t=config_error"
			return 1
		}
		nvram settmp "mwan_wan2_ip_t=0.0.0.0"
		nvram settmp "mwan_wan2_gateway_t=0.0.0.0"
		nvram settmp "mwan_wan2_state_t=connecting"
		/usr/sbin/pppd file "$PPPD_OPTIONS" || {
			log "failed to launch WAN2 PPPoE"
			nvram settmp "mwan_wan2_state_t=dial_error"
			return 1
		}
	else
		ifconfig "$WAN2_IF" 0.0.0.0 up
		nvram settmp "mwan_wan2_state_t=connecting"
		udhcpc -i "$WAN2_IF" -p "$UDHCPC_PID" -s /usr/bin/mwan-switch.sh -b -t 4 -T 4 -O 6
	fi
	log "dual WAN started: LAN1=$WAN2_IF LAN4=$LAN4_ROUTE 2.4G=$WIFI24_ROUTE 5G=$WIFI5_ROUTE"
}

ppp_event()
{
	local event="$1" ppp_if="$2" local_ip="$5" remote_ip="$6"
	read_config
	[ "$ENABLED" = "1" ] && [ "$WAN2_PROTO" = "pppoe" ] || return 0
	[ "$ppp_if" = "$WAN2_PPP_IF" ] && [ "${LINKNAME:-mwan2}" = "mwan2" ] || return 0
	case "$event" in
		up)
			[ -e "/proc/sys/net/ipv4/conf/$WAN2_PPP_IF/rp_filter" ] &&
				echo 0 > "/proc/sys/net/ipv4/conf/$WAN2_PPP_IF/rp_filter"
			install_wan2_ppp_route "$local_ip" "$remote_ip" || {
				log "failed to install PPPoE WAN2 route"
				nvram settmp "mwan_wan2_state_t=route_error"
				return 1
			}
			nvram settmp "mwan_wan2_ip_t=$local_ip"
			nvram settmp "mwan_wan2_gateway_t=$remote_ip"
			nvram settmp "mwan_wan2_state_t=connected"
			apply_firewall
			log "WAN2 PPPoE connected: $local_ip via $remote_ip"
			;;
		down)
			ip route flush table "$ROUTE_TABLE" 2>/dev/null
			add_local_routes
			ip route flush cache 2>/dev/null
			nvram settmp "mwan_wan2_ip_t=0.0.0.0"
			nvram settmp "mwan_wan2_gateway_t=0.0.0.0"
			nvram settmp "mwan_wan2_state_t=connecting"
			log "WAN2 PPPoE disconnected"
			;;
	esac
}

dhcp_event()
{
	local event="$1" gateway main_lan_ip main_lan_mask
	read_config
	[ "$interface" = "$WAN2_IF" ] || return 0
	case "$event" in
		deconfig)
			ifconfig "$WAN2_IF" 0.0.0.0 up
			ip route flush table "$ROUTE_TABLE" 2>/dev/null
			nvram settmp "mwan_wan2_ip_t=0.0.0.0"
			nvram settmp "mwan_wan2_gateway_t=0.0.0.0"
			nvram settmp "mwan_wan2_state_t=connecting"
			;;
		bound|renew)
			set -- $router
			gateway="$1"
			valid_ipv4 "$ip" && valid_netmask "$subnet" && valid_ipv4 "$gateway" || {
				log "ignored invalid DHCP lease on WAN2"
				return 1
			}
			subnets_overlap "$ip" "$subnet" "$gateway" "$subnet" || {
				log "ignored WAN2 gateway outside the DHCP subnet"
				return 1
			}
			main_lan_ip="$(nvget lan_ipaddr)"
			main_lan_mask="$(nvget lan_netmask)"
			if subnets_overlap "$ip" "$subnet" "$LAN2_IP" 255.255.255.0 ||
			   subnets_overlap "$ip" "$subnet" "$main_lan_ip" "$main_lan_mask"; then
				log "ignored conflicting DHCP subnet on WAN2"
				return 1
			fi
			ifconfig "$WAN2_IF" "$ip" netmask "$subnet" up
			install_wan2_route "$gateway" || {
				log "failed to install DHCP WAN2 route"
				nvram settmp "mwan_wan2_state_t=route_error"
				return 1
			}
			nvram settmp "mwan_wan2_ip_t=$ip"
			nvram settmp "mwan_wan2_gateway_t=$gateway"
			nvram settmp "mwan_wan2_state_t=connected"
			apply_firewall
			;;
	esac
}

case "${0##*/}" in
	mwan2-ip-up) ppp_event up "$@" ;;
	mwan2-ip-down) ppp_event down "$@" ;;
	*)
		case "$1" in
			start) start_service ;;
			firewall) apply_firewall ;;
			deconfig|bound|renew) dhcp_event "$1" ;;
			*) echo "Usage: $0 {start|firewall}" >&2; exit 1 ;;
		esac
		;;
esac
