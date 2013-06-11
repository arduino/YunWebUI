module("uploader.uploader", package.seeall)

--[[
local function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end
]]

function table.copy(t)
  local t2 = {}
  for k, v in pairs(t) do
    t2[k] = v
  end
  return t2
end

local function get_cert_and_key()
  local uci = require("luci.model.uci").cursor()
  uci.load("uhttpd")
  local cert = uci.get("uhttpd", "main", "cert")
  local key = uci.get("uhttpd", "main", "key")
  return cert, key
end

local function starts_with(str, substr, from_idx)
  return string.find(str, substr, from_idx) == from_idx
end

local function check_password(password)
  local uci = require("luci.model.uci")
  local config = uci.cursor()

  local sha256 = require("luci.sha256")
  local encrypted_pass = sha256.sha256(password)
  local stored_encrypted_pass = config:get_first("arduino", "arduino", "password")
  return encrypted_pass == stored_encrypted_pass
end

local function read_password(accumulator)
  local line = accumulator[1]
  local from_idx = 1
  local has_pwd = starts_with(line, "PWD", from_idx)
  if not has_pwd then
    return accumulator, 0, true
  end

  from_idx = from_idx + 3
  if #line < from_idx then
    return accumulator, 0, true
  end
  local pwd_length = tonumber(string.sub(line, from_idx, from_idx + 3))

  from_idx = from_idx + 4
  if #line < from_idx then
    return accumulator, 0, true
  end
  local pwd = string.sub(line, from_idx, from_idx + pwd_length - 1)

  if not check_password(pwd) then
    return accumulator, 0, true
  end

  table.remove(accumulator, 1)

  return accumulator, 1
end

local function read_sketch(accumulator)
  local local_accumulator = table.copy(accumulator)
  local line = local_accumulator[1]
  if line ~= "SKETCH" then
    return accumulator, 0, true
  end
  table.remove(local_accumulator, 1)

  if not local_accumulator[#local_accumulator] == "SKETCH_END" then
    return accumulator, 0
  end

  local sketch = {}
  local sketch_last_idx = 0
  local end_found = false
  for sketch_last_idx, line in ipairs(local_accumulator) do
    if line == "SKETCH_END" then
      end_found = true
      break
    end
    table.insert(sketch, line)
  end

  if not end_found then
    return accumulator, 0
  end

  table.remove(sketch)

  local io = require("io")
  for line in io.lines("/etc/arduino/Caterina-Yun.hex") do
    table.insert(sketch, line)
  end

  local final_sketch = io.open("/tmp/sketch.hex", "w+")
  if not final_sketch then
    return accumulator, 0, true
  end

  for idx, line in ipairs(sketch) do
    line = string.gsub(line, "\n", "")
    line = string.gsub(line, "\r", "")
    line = string.gsub(line, " ", "")
    if line ~= "" then
      final_sketch:write(line)
      final_sketch:write("\n")
    end
  end

  final_sketch:flush()
  final_sketch:close()

  while #local_accumulator > sketch_last_idx do
    table.remove(local_accumulator, 1)
  end
  return local_accumulator, 1
end

local function close_client(accumulator)
  local can_close = accumulator[1] == "EOF"
  table.remove(accumulator)
  return accumulator, 0, true
end

local nixio = require("nixio")
local tls_context = nixio.tls("server")
local cert, key = get_cert_and_key()
assert(tls_context:set_cert(cert, "asn1"))
assert(tls_context:set_key(key, "asn1"))
tls_context:set_verify("none")
assert(tls_context:set_ciphers("ALL"))

local server = nixio.bind("0.0.0.0", 9876)
assert(server:listen(3))

local buffer
function receive_line(socket)
  local function slice_of_buffer(index)
    local ret = string.sub(buffer, 1, index - 1)
    buffer = string.sub(buffer, index + 1)
    return ret
  end

  if buffer then
    local index = string.find(buffer, "\n")
    if index then
      return slice_of_buffer(index)
    end
  end

  local read_bytes = socket:read(4096)
  if read_bytes then
    buffer = buffer or ""
    buffer = buffer .. read_bytes
    buffer = string.gsub(string.gsub(buffer, "\r", "\n"), "\n\n", "\n")
  end
  local index = string.find(buffer, "\n")
  if not index then
    if buffer then
      return ""
    else
      return nil
    end
  end
  return slice_of_buffer(index)
end

function loop()
  while true do
    local client = server:accept()
    client:setsockopt("socket", "sndtimeo", 10)
    client:setsockopt("socket", "rcvtimeo", 10)
    client:setblocking(true)
    client = tls_context:create(client)
    if not client then
      client:close()
      break
    end

    local steps = { read_password, read_sketch, close_client }
    local current_step = 1
    local accumulator = {}
    local step_modifier
    local terminate

    while true do
      local line = receive_line(client)
      if line == nil then
        break
      end
      if line ~= "" then
        table.insert(accumulator, line)
        accumulator, step_modifier, terminate = steps[current_step](accumulator)
        if terminate then
          break
        end
        current_step = current_step + step_modifier
      end
    end

    client:send("OK\n");

    client:shutdown()
  end
end

while true do
  print(pcall(loop))
end