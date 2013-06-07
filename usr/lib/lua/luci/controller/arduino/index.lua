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

local function csv_to_array(text)
  local array = {}
  local line_parts;
  local lines = string.split(text, "\n")
  for i, line in ipairs(lines) do
    line_parts = string.split(line, "\t")
    table.insert(array, { code = line_parts[1], label = line_parts[2] })
  end
  return array
end

function config_get()
  local uci = luci.model.uci.cursor()
  uci:load("system")
  uci:load("wireless")

  local wifi_countries = csv_to_array(luci.util.exec("zcat /etc/arduino/wifi.csv.gz"))

  local timezones = {}
  local TZ = require("luci.sys.zoneinfo.tzdata").TZ
  for i, tz in ipairs(TZ) do
    table.insert(timezones, { code = tz[2], label = tz[1] })
  end

  local encryptions = {}
  encryptions[1] = { code = "none", label = "None" }
  encryptions[2] = { code = "wep", label = "WEP" }
  encryptions[3] = { code = "psk", label = "WPA" }
  encryptions[4] = { code = "psk2", label = "WPA2" }

  local ctx = {
    hostname = get_first(uci, "system", "system", "hostname"),
    timezone_desc = get_first(uci, "system", "system", "timezone_desc"),
    wifi = {
      ssid = get_first(uci, "arduino", "wifi-iface", "ssid"),
      encryption = get_first(uci, "arduino", "wifi-iface", "encryption"),
      password = get_first(uci, "arduino", "wifi-iface", "key"),
      country = uci:get("arduino", "radio0", "country")
    },
    countries = wifi_countries,
    timezones = timezones,
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

  if params["password"] and params["password"] ~= "" then
    local password = params["password"]
    luci.sys.user.setpasswd("root", password)

    local sha256 = require("luci.sha256")
    set_first(uci, "arduino", "arduino", "password", sha256.sha256(password))
  end

  if params["hostname"] then
    local hostname = string.gsub(params["hostname"], " ", "_")
    set_first(uci, "system", "system", "hostname", hostname)
  end

  if params["timezone_desc"] then
    local function find_timezone(timezone_desc)
      local TZ = require("luci.sys.zoneinfo.tzdata").TZ
      for i, tz in ipairs(TZ) do
        if tz[1] == timezone_desc then
          return tz[2]
        end
      end
      return nil
    end

    local timezone = find_timezone(params["timezone_desc"])
    if timezone then
      set_first(uci, "system", "system", "timezone", timezone)
      set_first(uci, "system", "system", "timezone_desc", params["timezone_desc"])
    end
  end

  uci:set("wireless", "radio0", "channel", "auto")
  uci:set("arduino", "radio0", "channel", "auto")
  set_first(uci, "wireless", "wifi-iface", "mode", "sta")
  set_first(uci, "arduino", "wifi-iface", "mode", "sta")

  if params["wifi.ssid"] then
    set_first(uci, "wireless", "wifi-iface", "ssid", params["wifi.ssid"])
    set_first(uci, "arduino", "wifi-iface", "ssid", params["wifi.ssid"])
  end
  if params["wifi.encryption"] then
    set_first(uci, "wireless", "wifi-iface", "encryption", params["wifi.encryption"])
    set_first(uci, "arduino", "wifi-iface", "encryption", params["wifi.encryption"])
  end
  if params["wifi.password"] then
    set_first(uci, "wireless", "wifi-iface", "key", params["wifi.password"])
    set_first(uci, "arduino", "wifi-iface", "key", params["wifi.password"])
  end
  if params["wifi.country"] then
    uci:set("wireless", "radio0", "country", params["wifi.country"])
    uci:set("arduino", "radio0", "country", params["wifi.country"])
  end

  uci:delete("network", "lan", "ipaddr")
  uci:delete("network", "lan", "netmask")

  uci:set("network", "lan", "proto", "dhcp")
  uci:set("arduino", "lan", "proto", "dhcp")

  set_first(uci, "arduino", "arduino", "wifi_reset_step", "clear")

  uci:commit("system")
  uci:commit("wireless")
  uci:commit("network")
  uci:commit("arduino")

  luci.template.render("arduino/rebooting", { hostname = get_first(uci, "system", "system", "hostname") })

  mluci.util.exec("reboot")
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
    local ix = luci.util.exec("LANG=en ifconfig wlan0 | grep HWaddr")
    local macaddr = string.gsub(ix:match("HWaddr ([^%s]+)"), ":", "")

    luci.template.render("arduino/board_reset", { name = "Arduino Yun-" .. macaddr })

    update_file = string.sub(update_file, rfind(update_file, "/"))
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