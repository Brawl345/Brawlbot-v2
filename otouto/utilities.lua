--[[
    utilities.lua
    Functions shared among otouto plugins.

    Copyright 2016 topkecleon <drew@otou.to>

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Affero General Public License version 3 as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License
    for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program; if not, write to the Free Software Foundation,
    Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
]]--

local utilities = {}

utf8 = require('lua-utf8')
ltn12 = require('ltn12')
http = require('socket.http')
https = require('ssl.https')
socket = require('socket')
URL = require('socket.url')
json = require("dkjson")
pcall(json.use_lpeg)
serpent = require("serpent")
redis = (loadfile "./otouto/redis.lua")()
OAuth = require "OAuth"
helpers = require "OAuth.helpers"

http.TIMEOUT = 10
https.TIMEOUT = 10

 -- For the sake of ease to new contributors and familiarity to old contributors,
 -- we'll provide a couple of aliases to real bindings here.
function utilities.send_message(chat_id, text, disable_web_page_preview, reply_to_message_id, use_markdown, reply_markup)
    local parse_mode
    if type(use_markdown) == 'string' then
        parse_mode = use_markdown
    elseif use_markdown == true then
        parse_mode = 'markdown'
    end
    return bindings.request(
        'sendMessage',
        {
			chat_id = chat_id,
            text = text,
            disable_web_page_preview = disable_web_page_preview,
            reply_to_message_id = reply_to_message_id,
            parse_mode = parse_mode,
			reply_markup = reply_markup
        }
    )
end

-- https://core.telegram.org/bots/api#editmessagetext
function utilities.edit_message(chat_id, message_id, text, disable_web_page_preview, use_markdown, reply_markup)
	local parse_mode
	if type(use_markdown) == 'string' then
	  parse_mode = use_markdown
	elseif use_markdown == true then
	  parse_mode = 'Markdown'
	end
	return bindings.request(
		'editMessageText',
		{
			chat_id = chat_id,
			message_id = message_id,
			text = text,
			disable_web_page_preview = disable_web_page_preview,
			parse_mode = parse_mode,
			reply_markup = reply_markup
		}
	)
end

function utilities.delete_message(chat_id, message_id)
  return utilities.edit_message(chat_id, message_id, '<i>Gelöschte Nachricht</i>', true, 'HTML')
end

function utilities.send_reply(msg, text, use_markdown, reply_markup)
    local parse_mode
    if type(use_markdown) == 'string' then
        parse_mode = use_markdown
    elseif use_markdown == true then
        parse_mode = 'markdown'
    end
    return bindings.request(
        'sendMessage',
        {
            chat_id = msg.chat.id,
            text = text,
            disable_web_page_preview = true,
            reply_to_message_id = msg.message_id,
            parse_mode = parse_mode,
			reply_markup = reply_markup
        }
    )
end

-- NOTE: Telegram currently only allows file uploads up to 50 MB
-- https://core.telegram.org/bots/api#sendphoto
function utilities.send_photo(chat_id, file, text, reply_to_message_id, reply_markup)
    if not file then return false end
	local output = bindings.request(
		'sendPhoto',
		{
			chat_id = chat_id,
			caption = text or nil,
			reply_to_message_id = reply_to_message_id,
			reply_markup = reply_markup
		},
		{
			photo = file
		}
	)
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#sendaudio
function utilities.send_audio(chat_id, file, reply_to_message_id, duration, performer, title)
    if not file then return false end
	local output = bindings.request(
		'sendAudio',
		{
			chat_id = chat_id,
			duration = duration or nil,
			performer = performer or nil,
			title = title or nil,
			reply_to_message_id = reply_to_message_id
		},
		{
			audio = file
		}
	)
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#senddocument
function utilities.send_document(chat_id, file, text, reply_to_message_id, reply_markup)
	if not file then return false end
	local output = bindings.request(
		'sendDocument',
		{
			chat_id = chat_id,
			caption = text or nil,
			reply_to_message_id = reply_to_message_id,
			reply_markup = reply_markup
		},
		{
			document = file
		}
	)
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#sendvideo
function utilities.send_video(chat_id, file, text, reply_to_message_id, duration, width, height)
	if not file then return false end
	local output = bindings.request(
		'sendVideo',
		{
			chat_id = chat_id,
			caption = text or nil,
			duration = duration or nil,
			width = width or nil,
			height = height or nil,
			reply_to_message_id = reply_to_message_id
		},
		{
			video = file
		}
	)
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- NOTE: Voice messages are .ogg files encoded with OPUS
-- https://core.telegram.org/bots/api#sendvoice
function utilities.send_voice(chat_id, file, reply_to_message_id, duration)
	if not file then return false end
	local output = bindings.request(
		'sendVoice',
		{
			chat_id = chat_id,
			duration = duration or nil,
			reply_to_message_id = reply_to_message_id
		},
		{
			voice = file
		}
	)
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#sendlocation
function utilities.send_location(chat_id, latitude, longitude, reply_to_message_id)
	return bindings.request(
		'sendLocation', 
		{
			chat_id = chat_id,
			latitude = latitude,
			longitude = longitude,
			reply_to_message_id = reply_to_message_id
		}
	)
end

-- NOTE: Venue is different from location: it shows information, such as the street adress or
-- title of the location with it.
-- https://core.telegram.org/bots/api#sendvenue
function utilities.send_venue(chat_id, latitude, longitude, reply_to_message_id, title, address)
	return bindings.request(
		'sendVenue',
		{
			chat_id = chat_id,
			latitude = latitude,
			longitude = longitude,
			title = title,
			address = address,
			reply_to_message_id = reply_to_message_id
		}
	)
end

-- https://core.telegram.org/bots/api#sendchataction
function utilities.send_typing(chat_id, action)
	return bindings.request(
		'sendChatAction',
		{
			chat_id = chat_id,
			action = action
		}
	)
end

-- https://core.telegram.org/bots/api#answercallbackquery
function utilities.answer_callback_query(callback, text, show_alert)
	return bindings.request(
		'answerCallbackQuery',
		{
			callback_query_id = callback.id,
			text = text,
			show_alert = show_alert
		}
	)
end

-- https://core.telegram.org/bots/api#getchat
function utilities.get_chat_info(chat_id)
	return bindings.request(
		'getChat',
		{
			chat_id = chat_id
		}
	)
end

-- https://core.telegram.org/bots/api#getchatadministrators
function utilities.get_chat_administrators(chat_id)
	return bindings.request(
		'getChatAdministrators',
		{
			chat_id = chat_id
		}
	)
end

-- https://core.telegram.org/bots/api#answerinlinequery
function utilities.answer_inline_query(inline_query, results, cache_time, is_personal, next_offset, switch_pm_text, switch_pm_parameter)
	return bindings.request(
		'answerInlineQuery',
		{
			inline_query_id	 = inline_query.id,
			results = results,
			cache_time = cache_time,
			is_personal = is_personal,
			next_offset = next_offset,
			switch_pm_text = switch_pm_text,
			switch_pm_parameter = switch_pm_parameter
		}
	)
end

function abort_inline_query(inline_query)
	return bindings.request(
		'answerInlineQuery',
		{
			inline_query_id	 = inline_query.id,
			cache_time = 5,
			is_personal = true
		}
	)
end

 -- get the indexed word in a string
function utilities.get_word(s, i)
    s = s or ''
    i = i or 1
    local n = 0
    for w in s:gmatch('%g+') do
        n = n + 1
        if n == i then return w end
    end
    return false
end

 -- Returns the string after the first space.
function utilities.input(s)
	if not s:find(' ') then
		return false
	end
	return s:sub(s:find(' ')+1)
end

function utilities.input_from_msg(msg)
	return utilities.input(msg.text) or (msg.reply_to_message and #msg.reply_to_message.text > 0 and msg.reply_to_message.text) or false
end

-- Trims whitespace from a string.
function utilities.trim(str)
	local s = str:gsub('^%s*(.-)%s*$', '%1')
	return s
end

-- Returns true if the string is blank/empty
function string:isempty()
  self = utilities.trim(self)
  return self == nil or self == ''
end

function get_name(msg)
   local name = msg.from.first_name
   if not name then
      name = msg.from.id
   end
   return name
end

-- http://www.lua.org/manual/5.2/manual.html#pdf-io.popen
function run_command(str)
  local cmd = io.popen(str)
  local result = cmd:read('*all')
  cmd:close()
  return result
end

function convert_timestamp(timestamp, date_format)
  return os.date(date_format, timestamp)
end

-- Saves file to $HOME/tmp/. If file_name isn't provided,
-- will get the text after the last "/" for filename
-- and content-type for extension
function download_to_file(url, file_name)
    print('url to download: '..url)
	if not file_name then
		file_name = '/tmp/' .. url:match('.+/(.-)$') or '/tmp/' .. os.time()
	else
	    file_name = '/tmp/' .. file_name
	end
	local body = {}
	local doer = http
	local do_redir = true
	if url:match('^https') then
		doer = https
		do_redir = false
	end
	local _, res = doer.request{
		url = url,
		sink = ltn12.sink.table(body),
		redirect = do_redir
	}
	if res ~= 200 then return false end
	local file = io.open(file_name, 'w+')
	file:write(table.concat(body))
	file:close()
	print('Saved to: '..file_name)
	return file_name
end

function vardump(value)
  print(serpent.block(value, {comment=false}))
end

 -- Loads a JSON file as a table.
function utilities.load_data(filename)
	local f = io.open(filename)
	if f then
		local s = f:read('*all')
		f:close()
		return json.decode(s)
	else
		return {}
	end
end

 -- Saves a table to a JSON file.
function utilities.save_data(filename, data)
	local s = json.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()
end

-- Returns file size as Integer
-- See: https://www.lua.org/pil/21.3.html
function get_file_size(file)
  local current = file:seek()      -- get current position
  local size = file:seek("end")    -- get file size
  file:seek("set", current)        -- restore position
  return tonumber(size)
end

 -- Gets coordinates for a location. Used by gMaps.lua, time.lua, weather.lua.
function utilities.get_coords(input, config)
  local url = 'https://maps.googleapis.com/maps/api/geocode/json?address='..URL.escape(input)..'&language=de'
  local jstr, res = https.request(url)
  if res ~= 200 then
    return config.errors.connection
  end

  local jdat = json.decode(jstr)
  if jdat.status == 'ZERO_RESULTS' then
    return config.errors.results
  end

  return {
	lat = jdat.results[1].geometry.location.lat,
	lon = jdat.results[1].geometry.location.lng,
	addr = jdat.results[1].formatted_address
  }
end

 -- Get the number of values in a key/value table.
function utilities.table_size(tab)
	local i = 0
	for _,_ in pairs(tab) do
		i = i + 1
	end
	return i
end

 -- Just an easy way to get a user's full name.
 -- Alternatively, abuse it to concat two strings like I do.
function utilities.build_name(first, last)
	if last then
		return first .. ' ' .. last
	else
		return first
	end
end

function utilities:handle_exception(err, message, log_chat)
    local output = string.format(
        '[%s]\n%s: %s\n%s\n',
        os.date('%F %T'),
        self.info.username,
        err or '',
        message
    )
    if log_chat then
        output = '<code>' .. utilities.html_escape(output) .. '</code>'
        return utilities.send_message(log_chat, output, true, nil, 'html')
    else
        print(output)
    end

end

function utilities.md_escape(text)
	return text:gsub('_', '\\_')
			:gsub('%[', '\\['):gsub('%]', '\\]')
			:gsub('%*', '\\*'):gsub('`', '\\`')
end

function utilities.html_escape(text)
	return text:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
end

utilities.triggers_meta = {}
utilities.triggers_meta.__index = utilities.triggers_meta
function utilities.triggers_meta:t(pattern, has_args)
	local username = self.username:lower()
	table.insert(self.table, '^'..self.cmd_pat..pattern..'$')
	table.insert(self.table, '^'..self.cmd_pat..pattern..'@'..username..'$')
	if has_args then
		table.insert(self.table, '^'..self.cmd_pat..pattern..'%s+[^%s]*')
		table.insert(self.table, '^'..self.cmd_pat..pattern..'@'..username..'%s+[^%s]*')
	end
	return self
end

function utilities.triggers(username, cmd_pat, trigger_table)
	local self = setmetatable({}, utilities.triggers_meta)
	self.username = username
	self.cmd_pat = cmd_pat
	self.table = trigger_table or {}
	return self
end

function utilities.enrich_user(user)
	user.id_str = tostring(user.id)
	user.name = utilities.build_name(user.first_name, user.last_name)
	return user
end

function utilities.enrich_message(msg)
	if not msg.text then msg.text = msg.caption or '' end
	msg.text_lower = msg.text:lower()
	msg.from = utilities.enrich_user(msg.from)
	msg.chat.id_str = tostring(msg.chat.id)
	if msg.reply_to_message then
		if not msg.reply_to_message.text then
			msg.reply_to_message.text = msg.reply_to_message.caption or ''
		end
		msg.reply_to_message.text_lower = msg.reply_to_message.text:lower()
		msg.reply_to_message.from = utilities.enrich_user(msg.reply_to_message.from)
		msg.reply_to_message.chat.id_str = tostring(msg.reply_to_message.chat.id)
	end
	if msg.forward_from then
		msg.forward_from = utilities.enrich_user(msg.forward_from)
	end
	if msg.new_chat_member then
		msg.new_chat_member = utilities.enrich_user(msg.new_chat_member)
	end
	if msg.left_chat_member then
		msg.left_chat_member = utilities.enrich_user(msg.left_chat_member)
	end
	return msg
end

function utilities.pretty_float(x)
	if x % 1 == 0 then
		return tostring(math.floor(x))
	else
		return tostring(x)
	end
end

 -- This table will store unsavory characters that are not properly displayed,
 -- or are just not fun to type.
utilities.char = {
	zwnj = '‌',
	arabic = '[\216-\219][\128-\191]',
	rtl_override = '‮',
	rtl_mark = '‏',
	em_dash = '—',
	utf_8 = '[%z\1-\127\194-\244][\128-\191]',
}

-- taken from http://stackoverflow.com/a/11130774/3163199
function scandir(directory)
  local i, t, popen = 0, {}, io.popen
  for filename in popen('ls -a "'..directory..'"'):lines() do
    i = i + 1
    t[i] = filename
  end
  return t
end

-- Returns a table with matches or nil
function match_pattern(pattern, text)
  if text then
    local matches = { string.match(text, pattern) }
    if next(matches) then
      return matches
	end
  end
  -- nil
end

function is_sudo(msg, config)
  local var = false
  -- Check if user id is sudoer
  if config.admin == msg.from.id then
    var = true
  end
  return var
end

function service_modify_msg(msg)
  if msg.new_chat_member then
	msg.text = '//tgservice new_chat_member'
	msg.text_lower = msg.text
  elseif msg.left_chat_member then
	msg.text = '//tgservice left_chat_member'
	msg.text_lower = msg.text
  elseif msg.new_chat_title then
	msg.text = '//tgservice new_chat_title'
	msg.text_lower = msg.text
  elseif msg.new_chat_photo then
	msg.text = '//tgservice new_chat_photo'
	msg.text_lower = msg.text
  elseif msg.group_chat_created then
	msg.text = '//tgservice group_chat_created'
	msg.text_lower = msg.text
  elseif msg.supergroup_chat_created then
	msg.text = '//tgservice supergroup_chat_created'
	msg.text_lower = msg.text
  elseif msg.channel_chat_created then
	msg.text = '//tgservice channel_chat_created'
	msg.text_lower = msg.text
  elseif msg.migrate_to_chat_id then
	msg.text = '//tgservice migrate_to_chat_id'
	msg.text_lower = msg.text
  elseif msg.migrate_from_chat_id then
	msg.text = '//tgservice migrate_from_chat_id'
	msg.text_lower = msg.text
  end
  return msg
end

function is_service_msg(msg)
  local var = false
  if msg.new_chat_member then
    var = true
  elseif msg.left_chat_member then
    var = true
  elseif msg.new_chat_title then
    var = true
  elseif msg.new_chat_photo then
    var = true
  elseif msg.group_chat_created then
    var = true
  elseif msg.supergroup_chat_created then
    var = true
  elseif msg.channel_chat_created then
    var = true
  elseif msg.migrate_to_chat_id then
    var = true
  elseif msg.migrate_from_chat_id then
    var = true
  end
  return var
end

-- Make a POST request
-- URL = obvious
-- Arguments = Things, that go into the body. If sending a file, use 'io.open('path/to/file', "r")'
-- Headers = Header table. If not set, we will set a few!
function post_petition(url, arguments, headers)
   local url, h = string.gsub(url, "http://", "")
   local url, hs = string.gsub(url, "https://", "")
   local post_prot = "http"
   if hs == 1 then
      post_prot = "https"
   end
   local response_body = {}
   local request_constructor = {
      url = post_prot..'://'..url,
      method = "POST",
      sink = ltn12.sink.table(response_body),
      headers = headers or {},
      redirect = false
   }

   local source = arguments
   if type(arguments) == "table" then
      source = helpers.url_encode_arguments(arguments)
   end

   if not headers then
     request_constructor.headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF8"
     request_constructor.headers["X-Accept"] = "application/json"
	 request_constructor.headers["Accept"] = "application/json"
   end
   if type(arguments) == 'userdata' then
     request_constructor.headers["Content-Length"] = get_file_size(source)
     request_constructor.source = ltn12.source.file(source)
   else 
     request_constructor.headers["Content-Length"] = tostring(#source)
     request_constructor.source = ltn12.source.string(source)
  end
   
   if post_prot == "http" then
     ok, response_code, response_headers, response_status_line = http.request(request_constructor)
   else
     ok, response_code, response_headers, response_status_line = https.request(request_constructor)
   end

   if not ok then
      return nil
   end

   response_body = json.decode(table.concat(response_body))

   return response_body, response_headers
end

function get_redis_hash(msg, var)
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    return 'chat:'..msg.chat.id..':'..var
  end
  if msg.chat.type == 'private' then
    return 'user:'..msg.from.id..':'..var
  end
end

function round(num, idp)
  if idp and idp>0 then
    local mult = 10^idp
    return math.floor(num * mult + 0.5) / mult
  end
  return math.floor(num + 0.5)
end

function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(str, fin)
  return fin=='' or string.sub(str,-string.len(fin)) == fin
end

function get_location(user_id)
  local hash = 'user:'..user_id
  local set_location = redis:hget(hash, 'location')
  if set_location == 'false' or set_location == nil then
    return false
  else
    return set_location
  end
end

function cache_data(plugin, query, data, timeout, typ, hash_field)
  -- How to: cache_data(pluginname, query_name, data_to_cache, expire_in_seconds, type, hash_field (if hash))
  local hash = 'telegram:cache:'..plugin..':'..query
  if timeout then
    print('Caching "'..query..'" from plugin '..plugin..' (expires in '..timeout..' seconds)')
  else
    print('Caching "'..query..'" from plugin '..plugin..' (expires never)')
  end
  if typ == 'key' then
    redis:set(hash, data)
  elseif typ == 'set' then
    -- make sure that you convert your data into a table:
	-- {"foo", "bar", "baz"} instead of
	-- {"bar" = "foo", "foo" = "bar", "bar" = "baz"}
	-- because other formats are not supported by redis (or I haven't found a way to store them)
    for _,str in pairs(data) do
	  redis:sadd(hash, str)
	end
  else
    redis:hmset(hash, data)
  end
  if timeout then
    redis:expire(hash, timeout)
  end
end

-- Caches file_id and last_modified
-- result = result of send_X() (see media.lua)
function cache_file(result, url, last_modified)
  local hash = 'telegram:cache:sent_file'
  if result.result.video then
    file_id = result.result.video.file_id
  elseif result.result.audio then
    file_id = result.result.audio.file_id
  elseif result.result.voice then
    file_id = result.result.voice.file_id
  elseif result.result.document then
    file_id = result.result.document.file_id
  elseif result.result.photo then
    local lv = #result.result.photo
    file_id = result.result.photo[lv].file_id
  elseif result.result.sticker then
    file_id = result.result.sticker.file_id
  end
  print('Caching File...')
  redis:hset(hash..':'..url, 'file_id', file_id)
  redis:hset(hash..':'..url, 'last_modified', last_modified)
  -- Why do we set a TTL? Because Telegram recycles outgoing file_id's
  -- See: https://core.telegram.org/bots/faq#can-i-count-on-file-ids-to-be-persistent
  redis:expire(hash..':'..url, 5259600) -- 2 months
end

function get_http_header(url)
  local doer = http
  local do_redir = true
  if url:match('^https') then
	doer = https
	do_redir = false
  end
  local _, code, header = doer.request {
	method = "HEAD",
	url = url,
	redirect = do_redir
  }
  if not header then return end
  return header, code
end

-- checks with If-Modified-Since header, if url has been changed
-- URL and Last-Modified heder are required
function was_modified_since(url, last_modified)
  local doer = http
  local do_redir = true
  if url:match('^https') then
	doer = https
	do_redir = false
  end
  local _, code, header = doer.request {
      url = url,
      method = "HEAD",
	  redirect = do_redir,
      headers = {
		["If-Modified-Since"] = last_modified
	  }
   }
  if code == 304 then
    return false, nil, code
  else
	if header["last-modified"] then
	  new_last_modified = header["last-modified"]
	elseif header["Last-Modified"] then
	  new_last_modified = header["Last-Modified"]
	end
    return true, new_last_modified, code
  end
end

-- only url is needed!
function get_cached_file(url, file_name, receiver, chat_action)
  local hash = 'telegram:cache:sent_file'
  local cached_file_id = redis:hget(hash..':'..url, 'file_id')
  local cached_last_modified = redis:hget(hash..':'..url, 'last_modified')

  if cached_last_modified then
    was_modified, new_last_modified, code = was_modified_since(url, cached_last_modified)
	if not was_modified then
	  print('File wasn\'t modified, skipping download...')
	  return cached_file_id, nil, true
	else
	  if code ~= 200 then
		redis:del(hash..':'..url)
		return
	  end
	  print('File was modified, redownloading...')
	  if receiver and chat_action then
	    utilities.send_typing(receiver, chat_action)
	  end
	  file = download_to_file(url, file_name)
	  return file, new_last_modified, false
	end
  end

  -- get last-modified and Content-Length header
  local header, code = get_http_header(url)

  -- file size limit is 50 MB
  if header then

    if header["Content-Length"] then
	  if tonumber(header["Content-Length"]) > 52420000 then
		print('file is too large, won\'t send!')
		return nil
	  end
	elseif header["content-length"] then
	  if tonumber(header["content-length"]) > 52420000 then
		print('file is too large, won\'t send!')
		return nil
	  end
	end
  
	if header["last-modified"] then
	  last_modified = header["last-modified"]
	elseif header["Last-Modified"] then
	  last_modified = header["Last-Modified"]
	end
  
  else
    last_modified = nil
  end
  
  if not last_modified then
	nocache = true
  else
    nocache = false
  end
  
  if receiver and chat_action then
    utilities.send_typing(receiver, chat_action)
  end
  
  if not nocache then
    file = download_to_file(url, file_name)
  else
    print('No Last-Modified header!')
    file = download_to_file(url, file_name)
  end
  return file, last_modified, nocache
end

-- converts total amount of seconds (e.g. 65 seconds) to human redable time (e.g. 1:05 minutes)
function makeHumanTime(totalseconds)
  local seconds = totalseconds % 60
  local minutes = math.floor(totalseconds / 60)
  local minutes = minutes % 60
  local hours = math.floor(totalseconds / 3600)
  if minutes == 00 and hours == 00 then
    if seconds == 1 then
	  return seconds..' Sekunde'
	else
      return seconds..' Sekunden'
	end
  elseif hours == 00 and minutes ~= 00 then
    if minutes == 1 then
	  return string.format("%02d:%02d", minutes, seconds)..' Minute'
	else
      return string.format("%02d:%02d", minutes, seconds)..' Minuten'
	end
  elseif hours ~= 00 then
    if hours == 1 then
	  return string.format("%02d:%02d:%02d", hours,  minutes, seconds)..' Stunde'
	else
      return string.format("%02d:%02d:%02d", hours,  minutes, seconds)..' Stunden'
	end
  end
end

function unescape(str)
  str = string.gsub( str, '&lt;', '<' )
  str = string.gsub( str, '&gt;', '>' )
  str = string.gsub( str, '&quot;', '"' )
  str = string.gsub( str, '&apos;', "'" )
  str = string.gsub( str, "&Auml;", "Ä")
  str = string.gsub( str, "&auml;", "ä")
  str = string.gsub( str, "&Ouml;", "Ö")
  str = string.gsub( str, "&ouml;", "ö")
  str = string.gsub( str, "Uuml;", "Ü")
  str = string.gsub( str, "&uuml;", "ü")
  str = string.gsub( str, "&szlig;", "ß")
  str = string.gsub( str, '&#(%d+);', function(n) return string.char(n) end )
  str = string.gsub( str, '&#x(%d+);', function(n) return string.char(tonumber(n,16)) end )
  str = string.gsub( str, '&amp;', '&' ) -- Be sure to do this after all others
  return str
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

-- Checks if bot was disabled on specific chat
function is_channel_disabled(msg)
  local hash = 'chat:'..msg.chat.id..':disabled'
  local disabled = redis:get(hash)
  
  if not disabled or disabled == "false" then
	return false
  end

  return disabled
end

 -- Converts a gross string back into proper UTF-8.
 -- Useful for fixing improper encoding caused by bad JSON escaping.
function utilities.fix_utf8(str)
    return string.char(utf8.codepoint(str, 1, -1))
end


return utilities