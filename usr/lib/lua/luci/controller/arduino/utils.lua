module("luci.controller.arduino.utils", package.seeall)

function index() end

function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function lines_from(file)
  lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

function rfind(s, c)
  last = 1
  while string.find(s, c, last, true) do
    last = string.find(s, c, last, true) + 1
  end
  return last
end

function param(name)
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

function update_file()
  update_file = luci.util.exec("update-file-available")
  if update_file and string.len(update_file) > 0 then
    return update_file
  end
  return nil
end

function get_first(cursor, config, type, option)
  return cursor:get_first(config, type, option)
end

function set_first(cursor, config, type, option, value)
  cursor:foreach(config, type, function(s)
    if s[".type"] == type then
      cursor:set(config, s[".name"], option, value)
    end
  end)
end
