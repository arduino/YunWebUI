module("uploader.uploader", package.seeall)

local socket = require("socket")
local io = require("io")
local server = assert(socket.bind("*", 9876))

--[[
--TODO comment out
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

local function starts_with(str, substr, from_idx)
  return string.find(str, substr, from_idx) == from_idx
end

local function check_password(encrypted_pass)
  local uci = require("luci.model.uci")
  local config = uci.cursor()

  stored_encrypted_pass = config:get_first("arduino", "arduino", "password")
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

  for line in io.lines("/etc/arduino/Caterina-Yun.hex") do
    table.insert(sketch, line)
  end

  final_sketch = io.open("/tmp/sketch.hex", "w+")
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

while true do
  local client = server:accept()
  client:settimeout(10)

  local steps = { read_password, read_sketch, close_client }
  local current_step = 1
  local accumulator = {}

  while true do
    local line, err = client:receive("*l")
    if err then
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

  client:close()
end
