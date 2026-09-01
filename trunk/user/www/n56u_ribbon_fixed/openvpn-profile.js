(function(global) {
	'use strict';

	var inlineSections = {
		'ca': 1,
		'cert': 1,
		'key': 1,
		'tls-auth': 1,
		'tls-crypt': 1,
		'tls-crypt-v2': 1
	};

	var clientGeneratedOptions = {
		'client': 1,
		'pull': 1,
		'remote': 1,
		'proto': 1,
		'dev': 1,
		'dev-type': 1,
		'ca': 1,
		'cert': 1,
		'key': 1,
		'tls-auth': 1,
		'tls-crypt': 1,
		'tls-crypt-v2': 1,
		'key-direction': 1,
		'auth-user-pass': 1,
		'auth': 1,
		'cipher': 1,
		'compress': 1,
		'comp-lzo': 1,
		'resolv-retry': 1,
		'nobind': 1,
		'persist-key': 1,
		'persist-tun': 1,
		'script-security': 1,
		'writepid': 1,
		'up': 1,
		'down': 1,
		'daemon': 1,
		'cd': 1
	};

	function normalizeProfile(text) {
		return String(text || '').replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');
	}

	function splitArgs(line) {
		var args = [];
		var match;
		var expression = /"([^"]*)"|'([^']*)'|([^\s]+)/g;

		while ((match = expression.exec(line)) !== null) {
			var value = match[1] !== undefined ? match[1] :
				(match[2] !== undefined ? match[2] : match[3]);
			if (value.charAt(0) == '#' || value.charAt(0) == ';')
				break;
			args.push(value);
		}

		return args;
	}

	function firstDirective(directives, name) {
		return directives[name] && directives[name].length ? directives[name][0] : null;
	}

	function protocolIndex(protocol, isServer) {
		protocol = String(protocol || 'udp').toLowerCase();
		if (protocol.indexOf('tcp6') === 0)
			return 3;
		if (protocol.indexOf('udp6') === 0)
			return 2;
		if (protocol == 'tcp' || protocol == 'tcp-client' || protocol == 'tcp-server')
			return 5;
		if (protocol == 'udp')
			return 4;
		if (protocol.indexOf('tcp') === 0)
			return 1;
		return 0;
	}

	function parseProfile(text, isServer) {
		var profile = normalizeProfile(text);
		var result = { ok: false, error: '', profile: profile };
		var directives = {};
		var sections = {};
		var output = [];
		var lines;
		var currentTag = '';
		var currentKnown = false;
		var sectionLines = [];
		var i;

		if (!profile || profile.indexOf('\0') >= 0) {
			result.error = 'empty';
			return result;
		}
		if (profile.length > 32768) {
			result.error = 'size';
			return result;
		}

		lines = profile.split('\n');
		for (i = 0; i < lines.length; i++) {
			var raw = lines[i];
			var trimmed = raw.replace(/^\s+|\s+$/g, '');
			var openTag;
			var closeTag;

			if (currentTag) {
				closeTag = trimmed.match(/^<\/([a-z0-9-]+)>$/i);
				if (closeTag) {
					if (closeTag[1].toLowerCase() != currentTag) {
						result.error = 'inline';
						return result;
					}
					if (currentKnown) {
						sections[currentTag] = (sections[currentTag] || '') + sectionLines.join('\n') + '\n';
					} else if (!isServer) {
						output.push(raw);
					}
					if (isServer)
						output.push(raw);
					currentTag = '';
					currentKnown = false;
					sectionLines = [];
					continue;
				}

				if (currentKnown)
					sectionLines.push(raw);
				if (isServer || !currentKnown)
					output.push(raw);
				continue;
			}

			openTag = trimmed.match(/^<([a-z0-9-]+)>$/i);
			if (openTag) {
				currentTag = openTag[1].toLowerCase();
				currentKnown = !!inlineSections[currentTag];
				if (isServer || !currentKnown)
					output.push(raw);
				continue;
			}

			if (!trimmed || trimmed.charAt(0) == '#' || trimmed.charAt(0) == ';') {
				output.push(raw);
				continue;
			}

			var args = splitArgs(trimmed);
			if (!args.length)
				continue;
			var option = args.shift().toLowerCase().replace(/^--/, '');
			if (!directives[option])
				directives[option] = [];
			directives[option].push(args);

			if (isServer || !clientGeneratedOptions[option])
				output.push(raw);
		}

		if (currentTag) {
			result.error = 'inline';
			return result;
		}

		var devArgs = firstDirective(directives, 'dev');
		if (!devArgs || !devArgs.length) {
			result.error = 'dev';
			return result;
		}
		var dev = devArgs[0].toLowerCase();
		if (dev.indexOf('tap') === 0)
			result.mode = 0;
		else if (dev.indexOf('tun') === 0)
			result.mode = 1;
		else {
			result.error = 'dev';
			return result;
		}

		var protoArgs = firstDirective(directives, 'proto');
		result.protocol = protocolIndex(protoArgs && protoArgs[0], isServer);

		if (isServer) {
			var modeArgs = firstDirective(directives, 'mode');
			if (!directives.server && !directives['server-bridge'] &&
				(!modeArgs || modeArgs[0].toLowerCase() != 'server')) {
				result.error = 'server';
				return result;
			}

			var portArgs = firstDirective(directives, 'port');
			result.port = portArgs && portArgs[0] ? parseInt(portArgs[0], 10) : 1194;
			result.profile = output.join('\n');
			result.ok = true;
			return result;
		}

		var remoteArgs = firstDirective(directives, 'remote');
		if (!remoteArgs || !remoteArgs[0]) {
			result.error = 'remote';
			return result;
		}
		result.remote = remoteArgs[0];
		result.port = remoteArgs[1] ? parseInt(remoteArgs[1], 10) : 1194;
		if (!result.port || result.port < 1 || result.port > 65535) {
			result.error = 'port';
			return result;
		}

		if (!sections.ca) {
			result.error = 'ca';
			return result;
		}

		var hasPassword = !!directives['auth-user-pass'];
		var passwordArgs = firstDirective(directives, 'auth-user-pass');
		var hasCertificate = !!(sections.cert && sections.key);
		if ((sections.cert && !sections.key) || (!sections.cert && sections.key)) {
			result.error = 'certificate';
			return result;
		}
		if (!hasPassword && !hasCertificate) {
			result.error = 'authentication';
			return result;
		}

		result.auth = hasPassword ? (hasCertificate ? 2 : 1) : 0;
		result.passwordFile = passwordArgs && passwordArgs[0] ? passwordArgs[0] : '';
		result.ca = sections.ca;
		result.cert = sections.cert || '';
		result.key = sections.key || '';
		result.tls = '';
		result.tlsMode = 0;
		if (sections['tls-crypt-v2']) {
			result.tls = sections['tls-crypt-v2'];
			result.tlsMode = 3;
		} else if (sections['tls-crypt']) {
			result.tls = sections['tls-crypt'];
			result.tlsMode = 2;
		} else if (sections['tls-auth']) {
			result.tls = sections['tls-auth'];
			result.tlsMode = 1;
		} else if (directives['tls-crypt-v2'] || directives['tls-crypt'] || directives['tls-auth']) {
			result.error = 'tls';
			return result;
		}

		result.extra = output.join('\n').replace(/^\s+|\s+$/g, '');
		if (result.ca.length > 8192 || result.cert.length > 8192 || result.key.length > 8192 ||
			result.tls.length > 8192 || result.extra.length > 8192) {
			result.error = 'size';
			return result;
		}

		result.ok = true;
		return result;
	}

	function prepareServerProfile(result) {
		var lines = result.profile.split('\n');
		var inInline = false;
		var replaced = false;
		var device = result.mode == 1 ? 'tun1' : 'tap1';
		var i;

		for (i = 0; i < lines.length; i++) {
			var trimmed = lines[i].replace(/^\s+|\s+$/g, '');
			if (/^<[a-z0-9-]+>$/i.test(trimmed)) {
				inInline = true;
				continue;
			}
			if (/^<\/[a-z0-9-]+>$/i.test(trimmed)) {
				inInline = false;
				continue;
			}
			if (!inInline && !replaced && /^dev\s+/i.test(trimmed.replace(/^--/, ''))) {
				lines[i] = 'dev ' + device;
				replaced = true;
			}
		}

		return lines.join('\n');
	}

	global.parseOpenVPNClientProfile = function(text) {
		return parseProfile(text, false);
	};
	global.parseOpenVPNServerProfile = function(text) {
		return parseProfile(text, true);
	};
	global.prepareOpenVPNServerProfile = prepareServerProfile;
})(this);
