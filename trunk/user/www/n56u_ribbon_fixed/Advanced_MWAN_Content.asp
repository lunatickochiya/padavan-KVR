<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - 双 WAN 分流</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script>
var $j = jQuery.noConflict();
var lan_ipaddr = '<% nvram_get_x("", "lan_ipaddr"); %>';
var lan_netmask = '<% nvram_get_x("", "lan_netmask"); %>';
var wan2_state = '<% nvram_get_x("", "mwan_wan2_state_t"); %>';
var wan2_ip = '<% nvram_get_x("", "mwan_wan2_ip_t"); %>';
var wan2_gateway = '<% nvram_get_x("", "mwan_wan2_gateway_t"); %>';

$j(document).ready(function() {
	init_itoggle('mwan_enable', update_visibility);
});

function initial() {
	var tab_index = 6;
	if (!support_mwan_switch()) {
		location.href = 'Advanced_WAN_Content.asp';
		return;
	}
	if (sw_mode == '4')
		tab_index -= 2;
	if (!support_ipv6())
		tab_index -= 1;
	show_banner(1);
	show_menu(5, 4, tab_index);
	show_footer();
	update_visibility();
	update_status();
}

function update_visibility() {
	var enabled = document.form.mwan_enable[0].checked;
	var static_mode = document.form.mwan_proto.value == 'static';
	showhide_div('mwan_settings', enabled);
	showhide_div('static_settings', enabled && static_mode);
}

function update_status() {
	var text = '未启用';
	var style = 'warning';
	if (document.form.mwan_enable[0].checked) {
		if (wan2_state == 'connected' && wan2_ip && wan2_ip != '0.0.0.0') {
			text = '已连接：' + wan2_ip;
			if (wan2_gateway && wan2_gateway != '0.0.0.0')
				text += '，网关 ' + wan2_gateway;
			style = 'success';
		} else if (wan2_state == 'route_error') {
			text = '地址已取得，但策略路由建立失败';
			style = 'important';
		} else {
			text = '正在连接或尚未取得地址';
		}
	}
	$('mwan_status').innerHTML = '<span class="label label-' + style + '">' + text + '</span>';
}

function valid_client_gateway(field) {
	var octets;
	if (!validate_ipaddr_final(field, ''))
		return false;
	octets = field.value.split('.');
	if (octets[3] == '0' || octets[3] == '255') {
		alert('WAN2 客户端网关不能使用网段地址或广播地址。');
		field.focus();
		return false;
	}
	return true;
}

function validForm() {
	if (!document.form.mwan_enable[0].checked)
		return true;
	if (!valid_client_gateway(document.form.mwan_lan_ip))
		return false;
	if (matchSubnet2(document.form.mwan_lan_ip.value, '255.255.255.0', lan_ipaddr, lan_netmask)) {
		alert('WAN2 客户端网段不能与主 LAN 网段相同。');
		document.form.mwan_lan_ip.focus();
		return false;
	}
	if (!validate_ipaddr_final(document.form.mwan_dns1, '') ||
	    !validate_ipaddr_final(document.form.mwan_dns2, ''))
		return false;
	if (document.form.mwan_proto.value == 'static') {
		if (!validate_ipaddr_final(document.form.mwan_ipaddr, '') ||
		    !validate_ipaddr_final(document.form.mwan_netmask, 'wan_netmask') ||
		    !validate_ipaddr_final(document.form.mwan_gateway, ''))
			return false;
		if (!matchSubnet(document.form.mwan_gateway.value, document.form.mwan_ipaddr.value,
		                 document.form.mwan_netmask.value)) {
			alert('WAN2 网关必须与 WAN2 IP 位于同一网段。');
			document.form.mwan_gateway.focus();
			return false;
		}
		if (matchSubnet2(document.form.mwan_ipaddr.value, document.form.mwan_netmask.value,
		                 lan_ipaddr, lan_netmask) ||
		    matchSubnet2(document.form.mwan_ipaddr.value, document.form.mwan_netmask.value,
		                 document.form.mwan_lan_ip.value, '255.255.255.0')) {
			alert('WAN2 上联网段不能与主 LAN 或 WAN2 客户端网段相同。');
			document.form.mwan_ipaddr.focus();
			return false;
		}
	}
	return true;
}

function applyRule() {
	if (!validForm())
		return;
	if (!confirm('应用双 WAN 设置将重启路由器，是否继续？'))
		return;
	showLoading();
	document.form.action_mode.value = ' Apply ';
	document.form.current_page.value = '/Advanced_MWAN_Content.asp';
	document.form.next_page.value = '';
	document.form.submit();
}
</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">
<div class="wrapper">
	<div class="container-fluid" style="padding-right: 0px">
		<div class="row-fluid">
			<div class="span3"><center><div id="logo"></div></center></div>
			<div class="span9"><div id="TopBanner"></div></div>
		</div>
	</div>
	<div id="Loading" class="popup_bg"></div>
	<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
	<form method="post" name="form" action="/start_apply.htm" target="hidden_frame">
		<input type="hidden" name="current_page" value="Advanced_MWAN_Content.asp">
		<input type="hidden" name="next_page" value="">
		<input type="hidden" name="next_host" value="">
		<input type="hidden" name="sid_list" value="MwanSwitchConf;">
		<input type="hidden" name="group_id" value="">
		<input type="hidden" name="action_mode" value="">
		<input type="hidden" name="action_script" value="">

		<div class="container-fluid">
			<div class="row-fluid">
				<div class="span3">
					<div class="well sidebar-nav side_nav" style="padding: 0px;">
						<ul id="mainMenu" class="clearfix"></ul>
						<ul class="clearfix"><li><div id="subMenu" class="accordion"></div></li></ul>
					</div>
				</div>
				<div class="span9">
					<div class="row-fluid"><div class="span12">
						<div class="box well grad_colour_dark_blue">
							<h2 class="box_head round_top"><#menu5_3#> - 双 WAN 分流</h2>
							<div class="round_bottom">
								<div class="row-fluid"><div id="tabMenu" class="submenuBlock"></div></div>
								<div class="alert alert-info" style="margin: 10px;">
									启用后物理 LAN1 固定作为 WAN2；选择 WAN2 的 LAN4 或无线主网络使用独立地址池。应用时路由器会重启。
								</div>
								<table width="100%" cellpadding="4" cellspacing="0" class="table">
									<tr><th width="50%">运行状态</th><td id="mwan_status"></td></tr>
									<tr><th>启用双 WAN</th><td>
										<div class="main_itoggle"><div id="mwan_enable_on_of">
											<input type="checkbox" id="mwan_enable_fake" <% nvram_match_x("", "mwan_enable", "1", "value=1 checked"); %><% nvram_match_x("", "mwan_enable", "0", "value=0"); %> />
										</div></div>
										<div style="position: absolute; margin-left: -10000px;">
											<input type="radio" value="1" name="mwan_enable" id="mwan_enable_1" <% nvram_match_x("", "mwan_enable", "1", "checked"); %> />
											<input type="radio" value="0" name="mwan_enable" id="mwan_enable_0" <% nvram_match_x("", "mwan_enable", "0", "checked"); %> />
										</div>
									</td></tr>
								</table>

								<div id="mwan_settings">
									<table width="100%" cellpadding="4" cellspacing="0" class="table">
										<tr><th colspan="2">WAN2 接入设置（物理 LAN1）</th></tr>
										<tr><th width="50%">接入方式</th><td>
											<select name="mwan_proto" class="input" onchange="update_visibility();">
												<option value="dhcp" <% nvram_match_x("", "mwan_proto", "dhcp", "selected"); %>>自动获取 IP（DHCP）</option>
												<option value="static" <% nvram_match_x("", "mwan_proto", "static", "selected"); %>>静态 IP</option>
											</select>
										</td></tr>
									</table>
									<div id="static_settings">
										<table width="100%" cellpadding="4" cellspacing="0" class="table">
											<tr><th width="50%">WAN2 IP 地址</th><td><input type="text" name="mwan_ipaddr" maxlength="15" class="input" value="<% nvram_get_x("", "mwan_ipaddr"); %>" onkeypress="return is_ipaddr(this,event);" /></td></tr>
											<tr><th>WAN2 子网掩码</th><td><input type="text" name="mwan_netmask" maxlength="15" class="input" value="<% nvram_get_x("", "mwan_netmask"); %>" onkeypress="return is_ipaddr(this,event);" /></td></tr>
											<tr><th>WAN2 网关</th><td><input type="text" name="mwan_gateway" maxlength="15" class="input" value="<% nvram_get_x("", "mwan_gateway"); %>" onkeypress="return is_ipaddr(this,event);" /></td></tr>
										</table>
									</div>
									<table width="100%" cellpadding="4" cellspacing="0" class="table">
										<tr><th width="50%">WAN2 客户端首选 DNS</th><td><input type="text" name="mwan_dns1" maxlength="15" class="input" value="<% nvram_get_x("", "mwan_dns1"); %>" onkeypress="return is_ipaddr(this,event);" /></td></tr>
										<tr><th>WAN2 客户端备用 DNS</th><td><input type="text" name="mwan_dns2" maxlength="15" class="input" value="<% nvram_get_x("", "mwan_dns2"); %>" onkeypress="return is_ipaddr(this,event);" /></td></tr>
									</table>

									<table width="100%" cellpadding="4" cellspacing="0" class="table">
										<tr><th colspan="2">终端出口分配</th></tr>
										<tr><th width="50%">WAN2 客户端网关（/24）</th><td><input type="text" name="mwan_lan_ip" maxlength="15" class="input" value="<% nvram_get_x("", "mwan_lan_ip"); %>" onkeypress="return is_ipaddr(this,event);" /><span class="help-inline">地址池自动使用 .100 - .249</span></td></tr>
										<tr><th>物理 LAN4 出口</th><td><select name="mwan_lan4" class="input"><option value="wan1" <% nvram_match_x("", "mwan_lan4", "wan1", "selected"); %>>WAN1</option><option value="wan2" <% nvram_match_x("", "mwan_lan4", "wan2", "selected"); %>>WAN2</option></select></td></tr>
										<tr><th>2.4G 主无线出口</th><td><select name="mwan_wifi24" class="input"><option value="wan1" <% nvram_match_x("", "mwan_wifi24", "wan1", "selected"); %>>WAN1</option><option value="wan2" <% nvram_match_x("", "mwan_wifi24", "wan2", "selected"); %>>WAN2</option></select></td></tr>
										<tr><th>5G 主无线出口</th><td><select name="mwan_wifi5" class="input"><option value="wan1" <% nvram_match_x("", "mwan_wifi5", "wan1", "selected"); %>>WAN1</option><option value="wan2" <% nvram_match_x("", "mwan_wifi5", "wan2", "selected"); %>>WAN2</option></select></td></tr>
									</table>
								</div>
								<table width="100%" cellpadding="4" cellspacing="0" class="table">
									<tr><td colspan="2"><center><input class="btn btn-primary" type="button" value="应用设置" onclick="applyRule();" /></center></td></tr>
								</table>
							</div>
						</div>
					</div></div>
				</div>
			</div>
		</div>
	</form>
	<div id="footer"></div>
</div>
</body>
</html>
