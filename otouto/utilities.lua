-- utilities.lua
-- Functions shared among plugins.

local utilities = {}

local HTTP = require('socket.http')
local ltn12 = require('ltn12')
local HTTPS = require('ssl.https')
local URL = require('socket.url')
local JSON = require('dkjson')
local http = require('socket.http')
local serpent = require("serpent")
local bindings = require('otouto.bindings')
local redis = (loadfile "./otouto/redis.lua")()
local mimetype = (loadfile "./otouto/mimetype.lua")()
local OAuth = require "OAuth"
local helpers = require "OAuth.helpers"

HTTP.timeout = 10

 -- For the sake of ease to new contributors and familiarity to old contributors,
 -- we'll provide a couple of aliases to real bindings here.
function utilities:send_message(chat_id, text, disable_web_page_preview, reply_to_message_id, use_markdown, reply_markup)
	return bindings.request(self, 'sendMessage', {
		chat_id = chat_id,
		text = text,
		disable_web_page_preview = disable_web_page_preview,
		reply_to_message_id = reply_to_message_id,
		parse_mode = use_markdown and 'Markdown' or nil,
		reply_markup = reply_markup
	} )
end

-- https://core.telegram.org/bots/api#editmessagetext
function utilities:edit_message(chat_id, message_id, text, disable_web_page_preview, use_markdown, reply_markup)
	return bindings.request(self, 'editMessageText', {
		chat_id = chat_id,
		message_id = message_id,
		text = text,
		disable_web_page_preview = disable_web_page_preview,
		parse_mode = use_markdown and 'Markdown' or nil,
		reply_markup = reply_markup
	} )
end

function utilities:send_reply(old_msg, text, use_markdown, reply_markup)
	return bindings.request(self, 'sendMessage', {
		chat_id = old_msg.chat.id,
		text = text,
		disable_web_page_preview = true,
		reply_to_message_id = old_msg.message_id,
		parse_mode = use_markdown and 'Markdown' or nil,
		reply_markup = reply_markup
	} )
end

-- NOTE: Telegram currently only allows file uploads up to 50 MB
-- https://core.telegram.org/bots/api#sendphoto
function utilities:send_photo(chat_id, file, text, reply_to_message_id, reply_markup)
    if not file then return false end
	local output = bindings.request(self, 'sendPhoto', {
		chat_id = chat_id,
		caption = text or nil,
		reply_to_message_id = reply_to_message_id,
		reply_markup = reply_markup
	}, {photo = file} )
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#sendaudio
function utilities:send_audio(chat_id, file, reply_to_message_id, duration, performer, title)
    if not file then return false end
	local output = bindings.request(self, 'sendAudio', {
		chat_id = chat_id,
		duration = duration or nil,
		performer = performer or nil,
		title = title or nil,
		reply_to_message_id = reply_to_message_id
	}, {audio = file} )
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#senddocument
function utilities:send_document(chat_id, file, text, reply_to_message_id, reply_markup)
	if not file then return false end
	local output = bindings.request(self, 'sendDocument', {
		chat_id = chat_id,
		caption = text or nil,
		reply_to_message_id = reply_to_message_id,
		reply_markup = reply_markup
	}, {document = file} )
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#sendvideo
function utilities:send_video(chat_id, file, text, reply_to_message_id, duration, width, height)
	if not file then return false end
	local output = bindings.request(self, 'sendVideo', {
		chat_id = chat_id,
		caption = text or nil,
		duration = duration or nil,
		width = width or nil,
		height = height or nil,
		reply_to_message_id = reply_to_message_id
	}, {video = file} )
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- NOTE: Voice messages are .ogg files encoded with OPUS
-- https://core.telegram.org/bots/api#sendvoice
function utilities:send_voice(chat_id, file, text, reply_to_message_id, duration)
	if not file then return false end
	local output = bindings.request(self, 'sendVoice', {
		chat_id = chat_id,
		duration = duration or nil,
		reply_to_message_id = reply_to_message_id
	}, {voice = file} )
	if string.match(file, '/tmp/') then
	  os.remove(file)
	  print("Deleted: "..file)
	end
	return output
end

-- https://core.telegram.org/bots/api#sendlocation
function utilities:send_location(chat_id, latitude, longitude, reply_to_message_id)
	return bindings.request(self, 'sendLocation', {
		chat_id = chat_id,
		latitude = latitude,
		longitude = longitude,
		reply_to_message_id = reply_to_message_id
	} )
end

-- NOTE: Venue is different from location: it shows information, such as the street adress or
-- title of the location with it.
-- https://core.telegram.org/bots/api#sendvenue
function utilities:send_venue(chat_id, latitude, longitude, reply_to_message_id, title, address)
	return bindings.request(self, 'sendVenue', {
		chat_id = chat_id,
		latitude = latitude,
		longitude = longitude,
		title = title,
		address = address,
		reply_to_message_id = reply_to_message_id
	} )
end

-- https://core.telegram.org/bots/api#sendchataction
function utilities:send_typing(chat_id, action)
	return bindings.request(self, 'sendChatAction', {
		chat_id = chat_id,
		action = action
	} )
end

-- https://core.telegram.org/bots/api#answercallbackquery
function utilities:answer_callback_query(callback, text, show_alert)
	return bindings.request(self, 'answerCallbackQuery', {
		callback_query_id = callback.id,
		text = text,
		show_alert = show_alert
	} )
end

-- https://core.telegram.org/bots/api#getchat
function utilities:get_chat_info(chat_id)
  return bindings.request(self, 'getChat', {
		chat_id = chat_id
	} )
end

-- https://core.telegram.org/bots/api#getchatadministrators
function utilities:get_chat_administrators(chat_id)
  return bindings.request(self, 'getChatAdministrators', {
		chat_id = chat_id
	} )
end

-- https://core.telegram.org/bots/api#answerinlinequery
function utilities:answer_inline_query(inline_query, results, cache_time, is_personal, next_offset, switch_pm_text, switch_pm_parameter)
  return bindings.request(self, 'answerInlineQuery', {
		inline_query_id	 = inline_query.id,
		results = results,
		cache_time = cache_time,
		is_personal = is_personal,
		next_offset = next_offset,
		switch_pm_text = switch_pm_text,
		switch_pm_parameter = switch_pm_parameter
	} )
end

 -- get the indexed word in a string
function utilities.get_word(s, i)
	s = s or ''
	i = i or 1
	local t = {}
	for w in s:gmatch('%g+') do
		table.insert(t, w)
	end
	return t[i] or false
end

 -- Like get_word(), but better.
 -- Returns the actual index.
function utilities.index(s)
	local t = {}
	for w in s:gmatch('%g+') do
		table.insert(t, w)
	end
	return t
end

 -- Returns the string after the first space.
function utilities.input(s)
	if not s:find(' ') then
		return false
	end
	return s:sub(s:find(' ')+1)
end

-- Calculates the length of the given string as UTF-8 characters
function utilities.utf8_len(s)
    local chars = 0
    for i = 1, string.len(s) do
        local b = string.byte(s, i)
        if b < 128 or b >= 192 then
            chars = chars + 1
        end
    end
    return chars
end

-- Trims whitespace from a string.
function utilities.trim(str)
	local s = str:gsub('^%s*(.-)%s*$', '%1')
	return s
end

-- Retruns true if the string is empty
function string:isempty()
  return self == nil or self == ''
end

-- Retruns true if the string is blank
function string:isblank()
  self = self:trim()
  return self:isempty()
end

function get_name(msg)
   local name = msg.from.first_name
   if name == nil then
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

function convert_timestamp(timestamp, format)
  local converted_date = run_command('date -d @'..timestamp..' +"'..format..'"')
  local converted_date = string.gsub(converted_date, '%\n', '')
  return converted_date
end

function string.starts(String, Start)
   return Start == string.sub(String,1,string.len(Start))
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
	local doer = HTTP
	local do_redir = true
	if url:match('^https') then
		doer = HTTPS
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
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)
	return data
end

 -- Saves a table to a JSON file.
function utilities.save_data(filename, data)
	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()
end

 -- Gets coordinates for a location. Used by gMaps.lua, time.lua, weather.lua.
function utilities.get_coords(input, config)

	local url = 'https://maps.googleapis.com/maps/api/geocode/json?address=' .. URL.escape(input)

	local jstr, res = HTTPS.request(url)
	if res ~= 200 then
		return config.errors.connection
	end

	local jdat = JSON.decode(jstr)
	if jdat.status == 'ZERO_RESULTS' then
		return config.errors.results
	end

	return {
		lat = jdat.results[1].geometry.location.lat,
		lon = jdat.results[1].geometry.location.lng
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

function utilities:resolve_username(input)
	input = input:gsub('^@', '')
	for _, user in pairs(self.database.users) do
		if user.username and user.username:lower() == input:lower() then
			local t = {}
			for key, val in pairs(user) do
				t[key] = val
			end
			return t
		end
	end
end

 -- Simpler than above function; only returns an ID.
 -- Returns nil if no ID is available.
function utilities:id_from_username(input)
	input = input:gsub('^@', '')
	for _, user in pairs(self.database.users) do
		if user.username and user.username:lower() == input:lower() then
			return user.id
		end
	end
end

 -- Simpler than below function; only returns an ID.
 -- Returns nil if no ID is available.
function utilities:id_from_message(msg)
	if msg.reply_to_message then
		return msg.reply_to_message.from.id
	else
		local input = utilities.input(msg.text)
		if input then
			if tonumber(input) then
				return tonumber(input)
			elseif input:match('^@') then
				return utilities.id_from_username(self, input)
			end
		end
	end
end

function utilities:user_from_message(msg, no_extra)
	local input = utilities.input(msg.text_lower)
	local target = {}
	if msg.reply_to_message then
		for k,v in pairs(self.database.users[msg.reply_to_message.from.id_str]) do
			target[k] = v
		end
	elseif input and tonumber(input) then
		target.id = tonumber(input)
		if self.database.users[input] then
			for k,v in pairs(self.database.users[input]) do
				target[k] = v
			end
		end
	elseif input and input:match('^@') then
		local uname = input:gsub('^@', '')
		for _,v in pairs(self.database.users) do
			if v.username and uname == v.username:lower() then
				for key, val in pairs(v) do
					target[key] = val
				end
			end
		end
		if not target.id then
			target.err = 'Sorry, I don\'t recognize that username.'
		end
	else
		target.err = 'Please specify a user via reply, ID, or username.'
	end

	if not no_extra then
		if target.id then
			target.id_str = tostring(target.id)
		end
		if not target.first_name then
			target.first_name = 'User'
		end
		target.name = utilities.build_name(target.first_name, target.last_name)
	end

	return target

end

function utilities:handle_exception(err, message, config)

	if not err then err = '' end

	local output = '\n[' .. os.date('%F %T', os.time()) .. ']\n' .. self.info.username .. ': ' .. err .. '\n' .. message .. '\n'

	if config.log_chat then
		output = '```' .. output .. '```'
		utilities.send_message(self, config.log_chat, output, true, nil, true)
	else
		print(output)
	end

end

-- MOVED TO DOWNLOAD_TO_FILE
function utilities.download_file(url, filename)
  return download_to_file(url, filename)
end

function utilities.markdown_escape(text)
	text = text:gsub('_', '\\_')
	text = text:gsub('%[', '\\[')
	text = text:gsub('%*', '\\*')
	text = text:gsub('`', '\\`')
	return text
end

utilities.md_escape = utilities.markdown_escape

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

function utilities.with_http_timeout(timeout, fun)
	local original = HTTP.TIMEOUT
	HTTP.TIMEOUT = timeout
	fun()
	HTTP.TIMEOUT = original
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
	if msg.new_chat_participant then
		msg.new_chat_participant = utilities.enrich_user(msg.new_chat_participant)
	end
	if msg.left_chat_participant then
		msg.left_chat_participant = utilities.enrich_user(msg.left_chat_participant)
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
	em_dash = '—'
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

-- Returns at table of lua files inside plugins
function plugins_names()
  local files = {}
  for k, v in pairs(scandir("otouto/plugins")) do
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

-- http://stackoverflow.com/a/6081639/3146627
function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if name then tmp = tmp .. name .. " = " end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

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
   request_constructor.headers["Content-Length"] = tostring(#source)
   request_constructor.source = ltn12.source.string(source)
   
   if post_prot == "http" then
     ok, response_code, response_headers, response_status_line = http.request(request_constructor)
   else
     ok, response_code, response_headers, response_status_line = HTTPS.request(request_constructor)
   end

   if not ok then
      return nil
   end

   response_body = JSON.decode(table.concat(response_body))

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

-- remove whitespace
function all_trim(s)
  return s:match( "^%s*(.-)%s*$" )
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
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

function cache_data(plugin, query, data, timeout, typ)
  -- How to: cache_data(pluginname, query_name, data_to_cache, expire_in_seconds)
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
  end
  print('Caching File...')
  redis:hset(hash..':'..url, 'file_id', file_id)
  redis:hset(hash..':'..url, 'last_modified', last_modified)
  -- Why do we set a TTL? Because Telegram recycles outgoing file_id's
  -- See: https://core.telegram.org/bots/faq#can-i-count-on-file-ids-to-be-persistent
  redis:expire(hash..':'..url, 5259600) -- 2 months
end

function get_http_header(url)
  local doer = HTTP
  local do_redir = true
  if url:match('^https') then
	doer = HTTPS
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

-- only url is needed!
function get_cached_file(url, file_name, receiver, chat_action, self)
  local hash = 'telegram:cache:sent_file'
  local cached_file_id = redis:hget(hash..':'..url, 'file_id')
  local cached_last_modified = redis:hget(hash..':'..url, 'last_modified')

  -- get last-modified and Content-Length header
  local header, code = get_http_header(url)
  if code ~= 200 then
    if cached_file_id then
      redis:del(hash..':'..url)
	end
    return
  end

  -- file size limit is 50 MB
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
  
  if not last_modified then
	nocache = true
  else
    nocache = false
  end
  
  if receiver and chat_action and self then
    utilities.send_typing(self, receiver, chat_action)
  end
  
  if not nocache then
    if last_modified == cached_last_modified then
      print('File not modified and already cached')
      nocache = true
	  file = cached_file_id
    else
	  print('File cached, but modified or not already cached. (Re)downloading...')
      file = download_to_file(url, file_name)
    end
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
    return seconds..' Sekunden'
  elseif hours == 00 and minutes ~= 00 then
    return string.format("%02d:%02d", minutes, seconds)..' Minuten'
  elseif hours ~= 00 then
    return string.format("%02d:%02d:%02d", hours,  minutes, seconds)..' Stunden'
  end
end

function is_blacklisted(msg)
  _blacklist = redis:smembers("telegram:img_blacklist")
  local var = false
  for v,word in pairs(_blacklist) do
    if string.find(string.lower(msg), string.lower(word)) then
      print("Wort steht auf der Blacklist!")
      var = true
      break
    end
  end
  return var
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

function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
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

return utilities