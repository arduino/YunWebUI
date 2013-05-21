module("luci.controller.arduino.webpanel", package.seeall)

local function file_exists(file)
	local f = io.open(file, "rb")
	if f then f:close() end
	return f ~= nil
end

local function lines_from(file)
	lines = {}
	for line in io.lines(file) do 
		lines[#lines + 1] = line
	end
	return lines
end

local function rfind(s, c)
	last = 1
	while string.find(s, c, last, true) do
		last = string.find(s, c, last, true) + 1
	end
	return last		
end

local function param(name)
	val = luci.http.formvalue(name)
	if val then
		val = luci.util.trim(val)
		if string.len(val) > 0 then
			return val
		end
		return nil
	end
	return nil
end

local function update_file()
	update_file = luci.util.exec("update-file-available")
	if update_file and string.len(update_file) > 0 then
		return update_file
	end
	return nil
end

local function get_first(cursor, config, type, option)
  return cursor:get_first(config, type, option)
end

local function set_first(cursor, config, type, option, value)
  cursor:foreach(config, type, function(s)
    if s[".type"] == type then
      cursor:set(config, s[".name"], option, value)
    end
  end)
end

function index()
	homepage = entry({"arduino"}, call("homepage"), _("Arduino Web Panel"), 10)
	homepage.dependent = false
	entry({"arduino", "ready"}, call("are_you_ready"), _("Arduino Web Panel"), 10)
	entry({"arduino", "config"}, call("config"), _("Arduino Web Panel"), 10)
	entry({"arduino", "reset_board"}, call("reset_board"), _("Arduino Web Panel"), 10)
end

function are_you_ready()
end

function homepage()
	local wa = require("luci.tools.webadmin")
	local network = luci.model.uci.cursor_state():get_all("network")
	local ifaces = {}

	for k, v in pairs(network) do
		if v[".type"] == "interface" and k ~= "loopback" then
			ix = luci.util.exec("LANG=en ifconfig " .. v["ifname"])
			address = ix and ix:match("inet addr:([^%s]+)") or "-"
			mac = ix and ix:match("HWaddr ([^%s]+)") or "-"
			netmask = ix and ix:match("Mask:([^%s]+)") or "-"

			ifaces[v["ifname"]] = {
				address = address,
				netmask = netmask,
				mac = mac:upper()
			}
		end
	end

	local deviceinfo = luci.sys.net.deviceinfo()
	for k, v in pairs(deviceinfo) do
		if ifaces[k] then
			ifaces[k]["rx"] = v[1] and wa.byte_format(tonumber(v[1])) or "-"
			ifaces[k]["tx"] = v[9] and wa.byte_format(tonumber(v[9])) or "-"
		end
	end

	local ctx = {
		hostname = luci.sys.hostname(), 
		ifaces = ifaces
	}

	if file_exists("/last_dmesg_with_wifi_errors.log") then
		ctx["last_log"] = lines_from("/last_dmesg_with_wifi_errors.log")
	end

	update_file = update_file()
	if update_file then
		update_file = string.sub(update_file, rfind(update_file, "/"))
		ctx["update_file"] = update_file
	end

	luci.template.render("arduino/homepage", ctx)
end

function config()
	if luci.http.formvalue("wifi.country") then
		config_post()
	else
		config_get()
	end
end

function config_get()
	local uci = luci.model.uci.cursor()
	uci:load("system")
	uci:load("wireless")

	countries = {}
	countries[1] = { code = "AL", name = "ALBANIA"}
	countries[2] = { code = "DZ", name = "ALGERIA"}
	countries[3] = { code = "AD", name = "ANDORRA"}
	countries[4] = { code = "AR", name = "ARGENTINA"}
	countries[5] = { code = "AW", name = "ARUBA"}
	countries[6] = { code = "AU", name = "AUSTRALIA"}
	countries[7] = { code = "AT", name = "AUSTRIA"}
	countries[8] = { code = "AZ", name = "AZERBAIJAN"}
	countries[9] = { code = "BH", name = "BAHRAIN"}
	countries[10] = { code = "BD", name = "BANGLADESH"}
	countries[11] = { code = "BB", name = "BARBADOS"}
	countries[12] = { code = "BY", name = "BELARUS"}
	countries[13] = { code = "BE", name = "BELGIUM"}
	countries[14] = { code = "BZ", name = "BELIZE"}
	countries[15] = { code = "BO", name = "BOLIVIA, PLURINATIONAL STATE OF"}
	countries[16] = { code = "BA", name = "BOSNIA AND HERZEGOVINA"}
	countries[17] = { code = "BR", name = "BRAZIL"}
	countries[18] = { code = "BN", name = "BRUNEI DARUSSALAM"}
	countries[19] = { code = "BG", name = "BULGARIA"}
	countries[20] = { code = "KH", name = "CAMBODIA"}
	countries[21] = { code = "CA", name = "CANADA"}
	countries[22] = { code = "CL", name = "CHILE"}
	countries[23] = { code = "CN", name = "CHINA"}
	countries[24] = { code = "CO", name = "COLOMBIA"}
	countries[25] = { code = "CR", name = "COSTA RICA"}
	countries[26] = { code = "HR", name = "CROATIA"}
	countries[27] = { code = "CY", name = "CYPRUS"}
	countries[28] = { code = "CZ", name = "CZECH REPUBLIC"}
	countries[29] = { code = "DK", name = "DENMARK"}
	countries[30] = { code = "DO", name = "DOMINICAN REPUBLIC"}
	countries[31] = { code = "EC", name = "ECUADOR"}
	countries[32] = { code = "EG", name = "EGYPT"}
	countries[33] = { code = "SV", name = "EL SALVADOR"}
	countries[34] = { code = "EE", name = "ESTONIA"}
	countries[35] = { code = "FI", name = "FINLAND"}
	countries[36] = { code = "FR", name = "FRANCE"}
	countries[37] = { code = "GE", name = "GEORGIA"}
	countries[38] = { code = "DE", name = "GERMANY"}
	countries[39] = { code = "GR", name = "GREECE"}
	countries[40] = { code = "GL", name = "GREENLAND"}
	countries[41] = { code = "GD", name = "GRENADA"}
	countries[42] = { code = "GU", name = "GUAM"}
	countries[43] = { code = "GT", name = "GUATEMALA"}
	countries[44] = { code = "HT", name = "HAITI"}
	countries[45] = { code = "HN", name = "HONDURAS"}
	countries[46] = { code = "HK", name = "HONG KONG"}
	countries[47] = { code = "HU", name = "HUNGARY"}
	countries[48] = { code = "IS", name = "ICELAND"}
	countries[49] = { code = "IN", name = "INDIA"}
	countries[50] = { code = "ID", name = "INDONESIA"}
	countries[51] = { code = "IR", name = "IRAN, ISLAMIC REPUBLIC OF"}
	countries[52] = { code = "IE", name = "IRELAND"}
	countries[53] = { code = "IL", name = "ISRAEL"}
	countries[54] = { code = "IT", name = "ITALY"}
	countries[55] = { code = "JM", name = "JAMAICA"}
	countries[56] = { code = "JP", name = "JAPAN"}
	countries[57] = { code = "JO", name = "JORDAN"}
	countries[58] = { code = "KZ", name = "KAZAKHSTAN"}
	countries[59] = { code = "KE", name = "KENYA"}
	countries[60] = { code = "KP", name = "KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF"}
	countries[61] = { code = "KR", name = "KOREA, REPUBLIC OF"}
	countries[62] = { code = "KW", name = "KUWAIT"}
	countries[63] = { code = "LV", name = "LATVIA"}
	countries[64] = { code = "LB", name = "LEBANON"}
	countries[65] = { code = "LI", name = "LIECHTENSTEIN"}
	countries[66] = { code = "LT", name = "LITHUANIA"}
	countries[67] = { code = "LU", name = "LUXEMBOURG"}
	countries[68] = { code = "MO", name = "MACAO"}
	countries[69] = { code = "MK", name = "MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF"}
	countries[70] = { code = "MY", name = "MALAYSIA"}
	countries[71] = { code = "MT", name = "MALTA"}
	countries[72] = { code = "MX", name = "MEXICO"}
	countries[73] = { code = "MC", name = "MONACO"}
	countries[74] = { code = "MA", name = "MOROCCO"}
	countries[75] = { code = "NP", name = "NEPAL"}
	countries[76] = { code = "NL", name = "NETHERLANDS"}
	countries[77] = { code = "NZ", name = "NEW ZEALAND"}
	countries[78] = { code = "NO", name = "NORWAY"}
	countries[79] = { code = "OM", name = "OMAN"}
	countries[80] = { code = "PK", name = "PAKISTAN"}
	countries[81] = { code = "PA", name = "PANAMA"}
	countries[82] = { code = "PG", name = "PAPUA NEW GUINEA"}
	countries[83] = { code = "PE", name = "PERU"}
	countries[84] = { code = "PH", name = "PHILIPPINES"}
	countries[85] = { code = "PL", name = "POLAND"}
	countries[86] = { code = "PT", name = "PORTUGAL"}
	countries[87] = { code = "PR", name = "PUERTO RICO"}
	countries[88] = { code = "QA", name = "QATAR"}
	countries[89] = { code = "RO", name = "ROMANIA"}
	countries[90] = { code = "RU", name = "RUSSIAN FEDERATION"}
	countries[91] = { code = "RW", name = "RWANDA"}
	countries[92] = { code = "BL", name = "SAINT BARTHÉLEMY"}
	countries[93] = { code = "SA", name = "SAUDI ARABIA"}
	countries[94] = { code = "RS", name = "SERBIA"}
	countries[95] = { code = "SG", name = "SINGAPORE"}
	countries[96] = { code = "SK", name = "SLOVAKIA"}
	countries[97] = { code = "SI", name = "SLOVENIA"}
	countries[98] = { code = "ZA", name = "SOUTH AFRICA"}
	countries[99] = { code = "ES", name = "SPAIN"}
	countries[100] = { code = "LK", name = "SRI LANKA"}
	countries[101] = { code = "SE", name = "SWEDEN"}
	countries[102] = { code = "CH", name = "SWITZERLAND"}
	countries[103] = { code = "SY", name = "SYRIAN ARAB REPUBLIC"}
	countries[104] = { code = "TW", name = "TAIWAN, PROVINCE OF CHINA"}
	countries[105] = { code = "TH", name = "THAILAND"}
	countries[106] = { code = "TT", name = "TRINIDAD AND TOBAGO"}
	countries[107] = { code = "TN", name = "TUNISIA"}
	countries[108] = { code = "TR", name = "TURKEY"}
	countries[109] = { code = "UA", name = "UKRAINE"}
	countries[110] = { code = "AE", name = "UNITED ARAB EMIRATES"}
	countries[111] = { code = "GB", name = "UNITED KINGDOM"}
	countries[112] = { code = "US", name = "UNITED STATES"}
	countries[113] = { code = "UY", name = "URUGUAY"}
	countries[114] = { code = "UZ", name = "UZBEKISTAN"}
	countries[115] = { code = "VE", name = "VENEZUELA, BOLIVARIAN REPUBLIC OF"}
	countries[116] = { code = "VN", name = "VIET NAM"}
	countries[117] = { code = "YE", name = "YEMEN"}
	countries[118] = { code = "ZW", name = "ZIMBABWE"}

	encryptions = {}
	encryptions[1] = { code = "none", name = "None" }
	encryptions[2] = { code = "wep", name = "WEP" }
	encryptions[3] = { code = "psk", name = "WPA" }
	encryptions[4] = { code = "psk2", name = "WPA2" }

	ctx = {
		hostname = get_first(uci, "system", "system", "hostname"),
		wifi = {
			ssid = get_first(uci, "wireless", "wifi-iface", "ssid"),
			encryption = get_first(uci, "wireless", "wifi-iface", "encryption"),
			password = get_first(uci, "wireless", "wifi-iface", "key"),
			country = uci:get("wireless", "radio0", "country")
		},
		countries = countries,
		encryptions = encryptions
	}

	luci.template.render("arduino/config", ctx)
end

function config_post()
	if param("password") then
		luci.sys.user.setpasswd("root", param("password"))
	end

	local uci = luci.model.uci.cursor()
	uci:load("system")
	uci:load("wireless")
	uci:load("network")

	if param("hostname") then
		local hostname = string.gsub(param("hostname"), " ", "_")
		set_first(uci, "system", "system", "hostname", hostname)
	end

	uci:set("wireless", "radio0", "channel", "auto")
	set_first(uci, "wireless", "wifi-iface", "mode", "sta")

	if param("wifi.ssid") then
	  set_first(uci, "wireless", "wifi-iface", "ssid", param("wifi.ssid"))
	end
	if param("wifi.encryption") then
	  set_first(uci, "wireless", "wifi-iface", "encryption", param("wifi.encryption"))
	end
	if param("wifi.password") then
	  set_first(uci, "wireless", "wifi-iface", "key", param("wifi.password"))
	end
	if param("wifi.country") then
		uci:set("wireless", "radio0", "country", param("wifi.country"))
	end

	uci:delete("network", "lan", "ifname")
	uci:delete("network", "lan", "type")
	uci:delete("network", "lan", "ipaddr")
	uci:delete("network", "lan", "netmask")

	uci:set("network", "lan", "proto", "dhcp")

	uci:commit("system")
	uci:commit("wireless")
	uci:commit("network")

	luci.template.render("arduino/rebooting", {})

	luci.util.exec("reboot")
end

function reset_board()
	update_file = update_file()
	if param("button") and update_file then
		luci.util.exec("blink-start 50")
		luci.util.exec("run-sysupgrade " .. update_file)
	end
end

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

