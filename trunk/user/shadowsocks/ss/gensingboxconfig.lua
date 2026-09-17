local cjson = require "cjson"

local server_section = arg[1]
local network = arg[2] or "tcp"
local local_port = arg[3] or "0"
local socks_port = arg[4] or "0"

local server_pipe = io.popen("dbus get ssconf_basic_json_" .. server_section)
local server = cjson.decode(server_pipe:read("*all"))
server_pipe:close()

local function nonempty(value)
	return value ~= nil and value ~= ""
end

local function tls_config()
	return {
		enabled = true,
		server_name = nonempty(server.tls_host) and server.tls_host or server.server,
		insecure = server.insecure == "1"
	}
end

local function transport_config()
	local transport = server.transport or "tcp"
	if transport == "tcp" and server.tcp_guise == "http" then
		return {
			type = "http",
			host = nonempty(server.http_host) and { server.http_host } or nil,
			path = nonempty(server.http_path) and server.http_path or "/"
		}
	elseif transport == "ws" then
		return {
			type = "ws",
			path = nonempty(server.ws_path) and server.ws_path or "/",
			headers = nonempty(server.ws_host) and { Host = server.ws_host } or nil
		}
	elseif transport == "h2" then
		return {
			type = "http",
			host = nonempty(server.h2_host) and { server.h2_host } or nil,
			path = nonempty(server.h2_path) and server.h2_path or "/"
		}
	elseif transport == "quic" then
		return { type = "quic" }
	end
	return nil
end

local protocol = server.singbox_protocol or "shadowsocks"
local outbound = {
	type = protocol,
	tag = "proxy",
	server = server.server,
	server_port = tonumber(server.server_port)
}

if protocol == "shadowsocks" then
	outbound.method = server.encrypt_method_ss or server.encrypt_method
	outbound.password = server.password or ""
	outbound.plugin = nonempty(server.plugin) and server.plugin or nil
	outbound.plugin_opts = nonempty(server.plugin_opts) and server.plugin_opts or nil
elseif protocol == "socks" then
	outbound.version = "5"
	outbound.username = nonempty(server.server_user) and server.server_user or nil
	outbound.password = nonempty(server.server_pwd) and server.server_pwd or nil
elseif protocol == "vmess" then
	outbound.uuid = server.vmess_id
	outbound.security = server.security or "auto"
	outbound.alter_id = tonumber(server.alter_id) or 0
	outbound.tls = server.tls == "1" and tls_config() or nil
	outbound.transport = transport_config()
elseif protocol == "vless" then
	outbound.uuid = server.vmess_id
	outbound.flow = server.flow == "xtls-rprx-vision" and server.flow or nil
	outbound.tls = server.tls == "1" and tls_config() or nil
	outbound.transport = transport_config()
elseif protocol == "trojan" then
	outbound.password = server.password or ""
	outbound.tls = tls_config()
	outbound.transport = transport_config()
elseif protocol == "hysteria2" then
	outbound.password = server.password or ""
	outbound.up_mbps = tonumber(server.singbox_up_mbps)
	outbound.down_mbps = tonumber(server.singbox_down_mbps)
	outbound.obfs = nonempty(server.singbox_obfs) and {
		type = server.singbox_obfs,
		password = server.singbox_obfs_password or ""
	} or nil
	outbound.tls = tls_config()
elseif protocol == "tuic" then
	outbound.uuid = server.vmess_id
	outbound.password = server.password or ""
	outbound.congestion_control = nonempty(server.singbox_congestion) and server.singbox_congestion or "cubic"
	outbound.udp_relay_mode = "native"
	outbound.zero_rtt_handshake = false
	outbound.heartbeat = "3s"
	outbound.tls = tls_config()
elseif protocol == "anytls" then
	outbound.password = server.password or ""
	outbound.tls = tls_config()
end

local multiplex_protocols = {
	shadowsocks = true,
	vmess = true,
	vless = true,
	trojan = true
}
if server.mux == "1" and multiplex_protocols[protocol] then
	if protocol ~= "vless" or not nonempty(outbound.flow) then
		outbound.multiplex = { enabled = true }
	end
end

local inbound
if socks_port ~= "0" then
	inbound = {
		type = "socks",
		tag = "socks-in",
		listen = "::",
		listen_port = tonumber(socks_port)
	}
elseif network == "udp" then
	inbound = {
		type = "tproxy",
		tag = "tproxy-udp",
		listen = "::",
		listen_port = tonumber(local_port),
		network = "udp"
	}
else
	inbound = {
		type = "redirect",
		tag = "redirect-tcp",
		listen = "::",
		listen_port = tonumber(local_port)
	}
end

local config = {
	log = {
		level = "warn",
		timestamp = true
	},
	inbounds = { inbound },
	outbounds = {
		outbound,
		{ type = "direct", tag = "direct" }
	},
	route = {
		final = "proxy",
		auto_detect_interface = true,
		rules = {
			{ action = "sniff", inbound = inbound.tag }
		}
	}
}

print(cjson.encode(config))
