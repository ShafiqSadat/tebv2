URL = require "socket.url"
http = require "socket.http"
https = require "ssl.https"
ltn12 = require "ltn12"
serpent = (loadfile "./libs/serpent.lua")()
feedparser = (loadfile "./libs/feedparser.lua")()
json = (loadfile "./libs/JSON.lua")()
mimetype = (loadfile "./libs/mimetype.lua")()
redis = (loadfile "./libs/redis.lua")()
JSON = (loadfile "./libs/dkjson.lua")()

http.TIMEOUT = 10

function get_receiver(msg)

  if msg.to.type == 'user' then
    return 'user#id'..msg.from.id
  end
  if msg.to.type == 'chat' then
    return 'chat#id'..msg.to.id
  end
  if msg.to.type == 'encr_chat' then
    return msg.to.print_name
  end
  if msg.to.type == 'channel' then
    return 'channel#id'..msg.to.id
  end
end

function is_chat_msg( msg )
  if msg.to.type == 'chat' then
    return true
  end
  return false
end

function string.random(length)
   local str = "";
   for i = 1, length do
      math.random(97, 122)
      str = str..string.char(math.random(97, 122));
   end
   return str;
end

function string.random(length)
   local str = "";
   for i = 1, length do
      math.random(97, 122)
      str = str..string.char(math.random(97, 122));
   end
   return str;
end

function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

-- DEPRECATED
function string.trim(s)
  print("string.trim(s) is DEPRECATED use string:trim() instead")
  return s:gsub("^%s*(.-)%s*$", "%1")
end

-- Removes spaces
function string:trim()
  return self:gsub("^%s*(.-)%s*$", "%1")
end

function vardump(value)
  print(serpent.block(value, {comment=false}))
end

-- taken from http://stackoverflow.com/a/11130774/3163199
function scandir(directory)
  local i, t, popen = 0, {}, io.popen
  for filename in popen('ls -a "'..directory..'"'):lines() do
    i = i + 1
    t[i] = filename
  end
  return t
end

-- http://www.lua.org/manual/5.2/manual.html#pdf-io.popen
function run_command(str)
  local cmd = io.popen(str)
  local result = cmd:read('*all')
  cmd:close()
  return result
end

-- User has privileges
function is_sudo(msg)
  local var = false
  -- Check users id in config
  for v,user in pairs(_config.sudo_users) do
    if user == msg.from.id then
      var = true
    end
  end
  return var
end

-- Returns the name of the sender
function get_name(msg)
  local name = msg.from.first_name
  if name == nil then
    name = msg.from.id
  end
  return name
end

-- Returns at table of lua files inside plugins
function plugins_names( )
  local files = {}
  for k, v in pairs(scandir("plugins")) do
    -- Ends with .lua
    if (v:match(".lua$")) then
      table.insert(files, v)
    end
  end
  return files
end

-- Function name explains what it does.
function file_exists(name)
  local f = io.open(name,"r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

-- Save into file the data serialized for lua.
-- Set uglify true to minify the file.
function serialize_to_file(data, file, uglify)
  file = io.open(file, 'w+')
  local serialized
  if not uglify then
    serialized = serpent.block(data, {
        comment = false,
        name = '_'
      })
  else
    serialized = serpent.dump(data)
  end
  file:write(serialized)
  file:close()
end

-- Returns true if the string is empty
function string:isempty()
  return self == nil or self == ''
end

-- Returns true if the string is blank
function string:isblank()
  self = self:trim()
  return self:isempty()
end

-- DEPRECATED!!!!!
function string.starts(String, Start)
  print("string.starts(String, Start) is DEPRECATED use string:starts(text) instead")
  return Start == string.sub(String,1,string.len(Start))
end

-- Returns true if String starts with Start
function string:starts(text)
  return text == string.sub(self,1,string.len(text))
end

function format_http_params(params, is_get)
  local str = ''
  -- If is get add ? to the beginning
  if is_get then str = '?' end
  local first = true -- Frist param
  for k,v in pairs (params) do
    if v then -- nil value
      if first then
        first = false
        str = str..k.. "="..v
      else
        str = str.."&"..k.. "="..v
      end
    end
  end
  return str
end

-- Check if user can use the plugin and warns user
-- Returns true if user was warned and false if not warned (is allowed)
function warns_user_not_allowed(plugin, msg)
  if not user_allowed(plugin, msg) then
    local text = 'This plugin requires privileged user'
    local receiver = get_receiver(msg)
    send_msg(receiver, text, ok_cb, false)
    return true
  else
    return false
  end
end

-- Check if user can use the plugin
function user_allowed(plugin, msg)
  if plugin.privileged and not is_sudo(msg) then
    return false
  end
  return true
end

-- Same as send_large_msg_callback but friendly params
function send_large_msg(destination, text)
  local cb_extra = {
    destination = destination,
    text = text
  }
  send_large_msg_callback(cb_extra, true)
end

-- If text is longer than 4096 chars, send multiple msg.
-- https://core.telegram.org/method/messages.sendMessage
function send_large_msg_callback(cb_extra, success, result)
  local text_max = 4096
  local destination = cb_extra.destination
  local text = cb_extra.text
  if not text or type(text) == 'boolean' then
    return
  end
  local text_len = string.len(text)
  local num_msg = math.ceil(text_len / text_max)

  if num_msg <= 1 then
    send_msg(destination, text, ok_cb, false)
  else

    local my_text = string.sub(text, 1, 4096)
    local rest = string.sub(text, 4096, text_len)

    local cb_extra = {
      destination = destination,
      text = rest
    }

    send_msg(destination, my_text, send_large_msg_callback, cb_extra)
  end
end
-- Returns a table with matches or nil
function match_pattern(pattern, text, lower_case)
  if text then
    local matches = {}
    if lower_case then
      matches = { string.match(text:lower(), pattern) }
    else
      matches = { string.match(text, pattern) }
    end
      if next(matches) then
        return matches
      end
  end
  -- nil
end

-- See http://stackoverflow.com/a/14899740
function unescape_html(str)
  local map = {
    ["lt"]  = "<",
    ["gt"]  = ">",
    ["amp"] = "&",
    ["quot"] = '"',
    ["apos"] = "'"
  }
  new = string.gsub(str, '(&(#?x?)([%d%a]+);)', function(orig, n, s)
    var = map[s] or n == "#" and string.char(s)
    var = var or n == "#x" and string.char(tonumber(s,16))
    var = var or orig
    return var
  end)
  return new
end

-- Workarrond to format the message as previously was received
function backward_msg_format (msg)
  for k,name in pairs({'from', 'to'}) do
    local longid = msg[name].id
    msg[name].id = msg[name].peer_id
    msg[name].peer_id = longid
    msg[name].type = msg[name].peer_type
  end
  if msg.action and (msg.action.user or msg.action.link_issuer) then
    local user = msg.action.user or msg.action.link_issuer
    local longid = user.id
    user.id = user.peer_id
    user.peer_id = longid
    user.type = user.peer_type
  end
  return msg
end

--Table Sort
function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
      i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end
