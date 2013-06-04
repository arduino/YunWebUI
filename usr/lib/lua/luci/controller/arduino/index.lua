module("luci.controller.arduino.index", package.seeall)

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
  local last = 1
  while string.find(s, c, last, true) do
    last = string.find(s, c, last, true) + 1
  end
  return last
end

local function param(name)
  local val = luci.http.formvalue(name)
  if val then
    val = luci.util.trim(val)
    if string.len(val) > 0 then
      return val
    end
    return nil
  end
  return nil
end

local function check_update_file()
  local update_file = luci.util.exec("update-file-available")
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

function http_error(code, text)
  luci.http.prepare_content("text/plain")
  luci.http.status(code)
  if text then
    luci.http.write(text)
  end
end

function read_gpg_pub_key()
  local gpg_pub_key_ascii_file = io.open("/etc/arduino/arduino_gpg.asc")
  local gpg_pub_key_ascii = ""
  for line in gpg_pub_key_ascii_file:lines() do
    gpg_pub_key_ascii = gpg_pub_key_ascii .. line .. "\\n"
  end
  return gpg_pub_key_ascii
end

dec_params = ""

function decrypt_pgp_message()
  local pgp_message = luci.http.formvalue("pgp_message")
  if pgp_message then
    if #dec_params > 0 then
      return dec_params
    end

    local pgp_enc_file = io.open("/tmp/pgp_message.txt", "w+")
    pgp_enc_file:write(pgp_message)
    pgp_enc_file:close()

    local json_input = luci.util.exec("cat /tmp/pgp_message.txt | gpg --no-default-keyring --secret-keyring /etc/arduino/arduino_gpg.sec --keyring /etc/arduino/arduino_gpg.pub --decrypt")
    local json = require("luci.json")
    dec_params = json.decode(json_input)
    return dec_params
  end
  return nil
end

function index()
  function luci.dispatcher.authenticator.arduinoauth(validator, accs, default)
    require("luci.controller.arduino.index")

    local dec_params = luci.controller.arduino.index.decrypt_pgp_message()
    local user = luci.http.formvalue("username") or (dec_params and dec_params["username"])
    local pass = luci.http.formvalue("password") or (dec_params and dec_params["password"])
    local basic_auth = luci.http.getenv("HTTP_AUTHORIZATION")

    if user and validator(user, pass) then
      return user
    end

    if basic_auth and basic_auth ~= "" then
      local decoded_basic_auth = nixio.bin.b64decode(string.sub(basic_auth, 7))
      user = string.sub(decoded_basic_auth, 0, string.find(decoded_basic_auth, ":") - 1)
      pass = string.sub(decoded_basic_auth, string.find(decoded_basic_auth, ":") + 1)
    end

    if user then
      if #pass ~= 64 and validator(user, pass) then
        return user
      elseif #pass == 64 then
        local uci = luci.model.uci.cursor()
        uci:load("arduino")
        local stored_encrypted_pass = uci:get_first("arduino", "arduino", "password")
        if pass == stored_encrypted_pass then
          return user
        end
      end
    end

    if basic_auth and basic_auth ~= "" then
      luci.controller.arduino.index.http_error(403)
    else
      local gpg_pub_key_ascii = luci.controller.arduino.index.read_gpg_pub_key()
      luci.template.render("arduino/set_password", { duser = default, fuser = user, pub_key = gpg_pub_key_ascii })
    end

    return false
  end

  local function protected_entry(path, target, title, order)
    local page = entry(path, target, title, order)
    page.sysauth = "root"
    page.sysauth_authenticator = "arduinoauth"
    return page
  end

  protected_entry({ "arduino" }, call("homepage"), _("Arduino Web Panel"), 10)
  protected_entry({ "arduino", "set_password" }, call("go_to_homepage"), _("Arduino Web Panel"), 10)
  protected_entry({ "arduino", "config" }, call("config"), _("Configure board"), 20).leaf = true
  protected_entry({ "arduino", "rebooting" }, template("arduino/rebooting"), _("Rebooting view"), 20).leaf = true
  protected_entry({ "arduino", "reset_board" }, call("reset_board"), _("Reset board"), 30).leaf = true
  protected_entry({ "arduino", "flash" }, call("flash_sketch"), _("Flash uploaded sketch"), 40).leaf = true
  protected_entry({ "arduino", "board" }, call("board_send_command"), _("Board send command"), 50).leaf = true
  protected_entry({ "arduino", "ready" }, call("ready"), _("Ready"), 60).leaf = true
end

function go_to_homepage()
  luci.http.redirect(luci.dispatcher.build_url("arduino"))
end

function homepage()
  local wa = require("luci.tools.webadmin")
  local network = luci.util.exec("LANG=en ifconfig | grep HWaddr")
  network = string.split(network, "\n")
  local ifnames = {}
  for i, v in ipairs(network) do
    local ifname = luci.util.trim(string.split(network[i], " ")[1])
    if ifname and ifname ~= "" then
      table.insert(ifnames, ifname)
    end
  end

  local ifaces_pretty_names = {
    wlan0 = "WiFi",
    eth1 = "Wired Ethernet"
  }

  local ifaces = {}
  for i, ifname in ipairs(ifnames) do
    local ix = luci.util.exec("LANG=en ifconfig " .. ifname)
    local mac = ix and ix:match("HWaddr ([^%s]+)") or "-"

    ifaces[ifname] = {
      mac = mac:upper(),
      pretty_name = ifaces_pretty_names[ifname]
    }

    local address = ix and ix:match("inet addr:([^%s]+)")
    local netmask = ix and ix:match("Mask:([^%s]+)")
    if address then
      ifaces[ifname]["address"] = address
      ifaces[ifname]["netmask"] = netmask
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

  local update_file = check_update_file()
  if update_file then
    update_file = string.sub(update_file, rfind(update_file, "/"))
    ctx["update_file"] = update_file
  end

  luci.template.render("arduino/homepage", ctx)
end

function config_get()
  local uci = luci.model.uci.cursor()
  uci:load("system")
  uci:load("wireless")

  local countries = {}
  countries[1] = { code = "AL", name = "Albania" }
  countries[2] = { code = "DZ", name = "Algeria" }
  countries[3] = { code = "AD", name = "Andorra" }
  countries[4] = { code = "AR", name = "Argentina" }
  countries[5] = { code = "AW", name = "Aruba" }
  countries[6] = { code = "AU", name = "Australia" }
  countries[7] = { code = "AT", name = "Austria" }
  countries[8] = { code = "AZ", name = "Azerbaijan" }
  countries[9] = { code = "BH", name = "Bahrain" }
  countries[10] = { code = "BD", name = "Bangladesh" }
  countries[11] = { code = "BB", name = "Barbados" }
  countries[12] = { code = "BY", name = "Belarus" }
  countries[13] = { code = "BE", name = "Belgium" }
  countries[14] = { code = "BZ", name = "Belize" }
  countries[15] = { code = "BO", name = "Bolivia, Plurinational State of" }
  countries[16] = { code = "BA", name = "Bosnia and Herzegovina" }
  countries[17] = { code = "BR", name = "Brazil" }
  countries[18] = { code = "BN", name = "Brunei Darussalam" }
  countries[19] = { code = "BG", name = "Bulgaria" }
  countries[20] = { code = "KH", name = "Cambodia" }
  countries[21] = { code = "CA", name = "Canada" }
  countries[22] = { code = "CL", name = "Chile" }
  countries[23] = { code = "CN", name = "China" }
  countries[24] = { code = "CO", name = "Colombia" }
  countries[25] = { code = "CR", name = "Costa Rica" }
  countries[26] = { code = "HR", name = "Croatia" }
  countries[27] = { code = "CY", name = "Cyprus" }
  countries[28] = { code = "CZ", name = "Czech Republic" }
  countries[29] = { code = "DK", name = "Denmark" }
  countries[30] = { code = "DO", name = "Dominican Republic" }
  countries[31] = { code = "EC", name = "Ecuador" }
  countries[32] = { code = "EG", name = "Egypt" }
  countries[33] = { code = "SV", name = "El Salvador" }
  countries[34] = { code = "EE", name = "Estonia" }
  countries[35] = { code = "FI", name = "Finland" }
  countries[36] = { code = "FR", name = "France" }
  countries[37] = { code = "GE", name = "Georgia" }
  countries[38] = { code = "DE", name = "Germany" }
  countries[39] = { code = "GR", name = "Greece" }
  countries[40] = { code = "GL", name = "Greenland" }
  countries[41] = { code = "GD", name = "Grenada" }
  countries[42] = { code = "GU", name = "Guam" }
  countries[43] = { code = "GT", name = "Guatemala" }
  countries[44] = { code = "HT", name = "Haiti" }
  countries[45] = { code = "HN", name = "Honduras" }
  countries[46] = { code = "HK", name = "Hong Kong" }
  countries[47] = { code = "HU", name = "Hungary" }
  countries[48] = { code = "IS", name = "Iceland" }
  countries[49] = { code = "IN", name = "India" }
  countries[50] = { code = "ID", name = "Indonesia" }
  countries[51] = { code = "IR", name = "Iran, Islamic Republic of" }
  countries[52] = { code = "IE", name = "Ireland" }
  countries[53] = { code = "IL", name = "Israel" }
  countries[54] = { code = "IT", name = "Italy" }
  countries[55] = { code = "JM", name = "Jamaica" }
  countries[56] = { code = "JP", name = "Japan" }
  countries[57] = { code = "JO", name = "Jordan" }
  countries[58] = { code = "KZ", name = "Kazakhstan" }
  countries[59] = { code = "KE", name = "Kenya" }
  countries[60] = { code = "KP", name = "Korea, Democratic People's Republic of" }
  countries[61] = { code = "KR", name = "Korea, Republic of" }
  countries[62] = { code = "KW", name = "Kuwait" }
  countries[63] = { code = "LV", name = "Latvia" }
  countries[64] = { code = "LB", name = "Lebanon" }
  countries[65] = { code = "LI", name = "Liechtenstein" }
  countries[66] = { code = "LT", name = "Lithuania" }
  countries[67] = { code = "LU", name = "Luxembourg" }
  countries[68] = { code = "MO", name = "Macao" }
  countries[69] = { code = "MK", name = "Macedonia, Republic of" }
  countries[70] = { code = "MY", name = "Malaysia" }
  countries[71] = { code = "MT", name = "Malta" }
  countries[72] = { code = "MX", name = "Mexico" }
  countries[73] = { code = "MC", name = "Monaco" }
  countries[74] = { code = "MA", name = "Morocco" }
  countries[75] = { code = "NP", name = "Nepal" }
  countries[76] = { code = "NL", name = "Netherlands" }
  countries[77] = { code = "NZ", name = "New Zealand" }
  countries[78] = { code = "NO", name = "Norway" }
  countries[79] = { code = "OM", name = "Oman" }
  countries[80] = { code = "PK", name = "Pakistan" }
  countries[81] = { code = "PA", name = "Panama" }
  countries[82] = { code = "PG", name = "Papua New Guinea" }
  countries[83] = { code = "PE", name = "Peru" }
  countries[84] = { code = "PH", name = "Philippines" }
  countries[85] = { code = "PL", name = "Poland" }
  countries[86] = { code = "PT", name = "Portugal" }
  countries[87] = { code = "PR", name = "Puerto Rico" }
  countries[88] = { code = "QA", name = "Qatar" }
  countries[89] = { code = "RO", name = "Romania" }
  countries[90] = { code = "RU", name = "Russian Federation" }
  countries[91] = { code = "RW", name = "Rwanda" }
  countries[92] = { code = "BL", name = "Saint Barthélemy" }
  countries[93] = { code = "SA", name = "Saudi Arabia" }
  countries[94] = { code = "RS", name = "Serbia" }
  countries[95] = { code = "SG", name = "Singapore" }
  countries[96] = { code = "SK", name = "Slovakia" }
  countries[97] = { code = "SI", name = "Slovenia" }
  countries[98] = { code = "ZA", name = "South Africa" }
  countries[99] = { code = "ES", name = "Spain" }
  countries[100] = { code = "LK", name = "Sri Lanka" }
  countries[101] = { code = "SE", name = "Sweden" }
  countries[102] = { code = "CH", name = "Switzerland" }
  countries[103] = { code = "SY", name = "Syrian Arab Republic" }
  countries[104] = { code = "TW", name = "Taiwan, Province of China" }
  countries[105] = { code = "TH", name = "Thailand" }
  countries[106] = { code = "TT", name = "Trinidad and Tobago" }
  countries[107] = { code = "TN", name = "Tunisia" }
  countries[108] = { code = "TR", name = "Turkey" }
  countries[109] = { code = "UA", name = "Ukraine" }
  countries[110] = { code = "AE", name = "United Arab Emirates" }
  countries[111] = { code = "GB", name = "United Kingdom" }
  countries[112] = { code = "US", name = "United States" }
  countries[113] = { code = "UY", name = "Uruguay" }
  countries[114] = { code = "UZ", name = "Uzbekistan" }
  countries[115] = { code = "VE", name = "Venezuela, Bolivarian Republic of" }
  countries[116] = { code = "VN", name = "Viet Nam" }
  countries[117] = { code = "YE", name = "Yemen" }
  countries[118] = { code = "ZW", name = "Zimbabwe" }

  local encryptions = {}
  encryptions[1] = { code = "none", name = "None" }
  encryptions[2] = { code = "wep", name = "WEP" }
  encryptions[3] = { code = "psk", name = "WPA" }
  encryptions[4] = { code = "psk2", name = "WPA2" }

  local ctx = {
    hostname = get_first(uci, "system", "system", "hostname"),
    wifi = {
      ssid = get_first(uci, "wireless", "wifi-iface", "ssid"),
      encryption = get_first(uci, "wireless", "wifi-iface", "encryption"),
      password = get_first(uci, "wireless", "wifi-iface", "key"),
      country = uci:get("wireless", "radio0", "country")
    },
    countries = countries,
    encryptions = encryptions,
    pub_key = luci.controller.arduino.index.read_gpg_pub_key()
  }

  luci.template.render("arduino/config", ctx)
end

function config_post()
  local params = decrypt_pgp_message()

  local uci = luci.model.uci.cursor()
  uci:load("system")
  uci:load("wireless")
  uci:load("network")
  uci:load("arduino")

  if params["password"] then
    local password = params["password"]
    luci.sys.user.setpasswd("root", password)

    local sha256 = require("luci.sha256")
    set_first(uci, "arduino", "arduino", "password", sha256.sha256(password))
  end

  if params["hostname"] then
    local hostname = string.gsub(params["hostname"], " ", "_")
    set_first(uci, "system", "system", "hostname", hostname)
  end

  uci:set("wireless", "radio0", "channel", "auto")
  set_first(uci, "wireless", "wifi-iface", "mode", "sta")

  if params["wifi.ssid"] then
    set_first(uci, "wireless", "wifi-iface", "ssid", params["wifi.ssid"])
  end
  if params["wifi.encryption"] then
    set_first(uci, "wireless", "wifi-iface", "encryption", params["wifi.encryption"])
  end
  if params["wifi.password"] then
    set_first(uci, "wireless", "wifi-iface", "key", params["wifi.password"])
  end
  if params["wifi.country"] then
    uci:set("wireless", "radio0", "country", params["wifi.country"])
  end

  uci:delete("network", "lan", "ipaddr")
  uci:delete("network", "lan", "netmask")

  uci:set("network", "lan", "proto", "dhcp")

  uci:commit("system")
  uci:commit("wireless")
  uci:commit("network")
  uci:commit("arduino")

  luci.template.render("arduino/rebooting", {})

  luci.util.exec("reboot")
end

function config()
  if luci.http.getenv("REQUEST_METHOD") == "POST" then
    config_post()
  else
    config_get()
  end
end

function reset_board()
  local update_file = check_update_file()
  if param("button") and update_file then
    luci.util.exec("blink-start 50")
    luci.util.exec("run-sysupgrade " .. update_file)
  end
end

function ready()
  luci.http.status(200)
  return
end

function flash_sketch()
  local uploaded = "/tmp/sketch.hex"

  local fd = io.open(uploaded)
  if not fd then
    http_error(500, "Unable to open file for writing")
    return
  end

  luci.util.exec("kill-bridge")
  local command = "run-avrdude " .. uploaded
  if param("params") then
    command = command .. " '" .. param("params") .. "'"
  end

  local output = luci.util.exec(command)
  luci.http.prepare_content("text/plain")
  luci.http.write(output)
end

function board_send_command()
  local method = luci.http.getenv("REQUEST_METHOD")
  local parts = luci.util.split(luci.http.getenv("PATH_INFO"), "/")
  local command = parts[4]
  if not command or command == "" then
    http_error(404)
    return
  end
  local params = {}
  for idx, param in ipairs(parts) do
    if idx > 4 then
      table.insert(params, param)
    end
  end

  local bridge_request = {
    command = command
  }
  -- TODO check method?
  if command == "raw" then
    bridge_request["data"] = table.concat(params, "/")
  elseif command == "get" and params[1] and params[1] ~= "" then
    bridge_request["key"] = params[1]
  elseif command == "put" and params[1] and params[1] ~= "" and params[2] then
    bridge_request["key"] = params[1]
    bridge_request["value"] = params[2]
  else
    http_error(404)
    return
  end

  local sock, code, msg = nixio.connect("127.0.0.1", 5700)
  if not sock then
    code = code or ""
    msg = msg or ""
    http_error(500, "nil socket, " .. code .. " " .. msg)
    return
  end

  sock:setsockopt("socket", "sndtimeo", 5)
  sock:setsockopt("socket", "rcvtimeo", 5)

  local json = require("luci.json")

  sock:writeall(json.encode(bridge_request) .. "\n")

  local response_text = ""
  while true do
    local bytes = sock:recv(4096)
    if bytes then
      response_text = response_text .. bytes
    end

    if response_text == "" then
      luci.http.status(200)
      return
    end

    local json_response = json.decode(response_text)
    if json_response then
      luci.http.prepare_content("application/json")
      luci.http.status(200)
      luci.http.write(json.encode(json_response))
      sock:close()
      return
    end

    if not bytes then
      http_error(500, "Empty response")
      return
    end
  end
end