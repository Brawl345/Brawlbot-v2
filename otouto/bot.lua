--[[
    bot.lua
    The heart and sole of otouto, ie the init and main loop.

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

local bot = {}

bot.version = '2.2.7'

function bot:init(config) -- The function run when the bot is started or reloaded.
    assert(config.bot_api_key, 'Dein Bot-Token ist nicht in der Config gesetzt!')
    bindings = require('otouto.bindings').init(config.bot_api_key)
	utilities = require('otouto.utilities')
	cred_data = load_cred()

	-- Fetch bot information. Try until it succeeds.
	repeat
		print('Fetching bot information...')
		self.info = bindings.getMe()
	until self.info
	self.info = self.info.result

	-- Load the "database"! ;)
	if not self.database then
		self.database = utilities.load_data(self.info.username..'.db')
	end

	self.plugins = {} -- Load plugins.
	enabled_plugins = load_plugins()
	for k,v in pairs(enabled_plugins) do
		local p = require('otouto.plugins.'..v)
		-- print('loading plugin',v)
		self.plugins[k] = p
	    self.plugins[k].name = v
		if p.init then p.init(self, config) end
	end
	
	print('Bot started successfully as:\n@' .. self.info.username .. ', AKA ' .. self.info.first_name ..' ('..self.info.id..')')

	-- Set loop variables
	self.last_update = self.last_update or 0 -- Update offset.
	self.last_cron = self.last_cron or os.date('%M') -- Last cron job.
	self.last_database_save = self.last_database_save or os.date('%H') -- Last db save.
	self.is_started = true -- and whether or not the bot should be running.
end

function bot:on_msg_receive(msg, config) -- The fn run whenever a message is received.
	-- remove comment to enable debugging
    -- vardump(msg)
	
	if msg.date < os.time() - 5 then return end -- Do not process old messages.

	msg = utilities.enrich_message(msg)

	if msg.reply_to_message then
		msg.reply_to_message.text = msg.reply_to_message.text or msg.reply_to_message.caption or ''
	end

	-- Support deep linking.
	if msg.text:match('^'..config.cmd_pat..'start .+') then
		msg.text = config.cmd_pat .. utilities.input(msg.text)
		msg.text_lower = msg.text:lower()
	end

	-- gsub out user name if multiple bots are in the same group
	if msg.text:match(config.cmd_pat..'([A-Za-z0-9-_-]+)@'..self.info.username) then
	  msg.text = string.gsub(msg.text, config.cmd_pat..'([A-Za-z0-9-_-]+)@'..self.info.username, "/%1")
	  msg.text_lower = msg.text:lower()
	end

	msg = pre_process_msg(self, msg, config)
	if not msg then return end -- deleted by banning
	
	if is_service_msg(msg) then
	  msg = service_modify_msg(msg)
	end

	for _, plugin in ipairs(self.plugins) do
	  match_plugins(self, msg, config, plugin)
	end
end

function bot:on_callback_receive(callback, msg, config) -- whenever a new callback is received
  -- remove comments to enable debugging
  -- vardump(msg)
  -- vardump(callback)

  if msg.date < os.time() - 3600 then -- Do not process old messages.
    utilities.answer_callback_query(callback, 'Nachricht älter als eine Stunde, bitte sende den Befehl selbst noch einmal.', true)
    return
  end
  
  if not callback.data:find(':') then
    utilities.answer_callback_query(callback, 'Ungültiger CallbackQuery: Kein Parameter.')
	return
  end

  -- Check if user is blocked
  local user_id = callback.from.id
  local chat_id = msg.chat.id
  if redis:get('blocked:'..user_id) then
    utilities.answer_callback_query(callback, 'Du darfst den Bot nicht nutzen!', true)
	return
  end
 
  -- Check if user is banned
  local banned = redis:get('banned:'..chat_id..':'..user_id)
  if banned then
    utilities.answer_callback_query(callback, 'Du darfst den Bot nicht nutzen!', true)
	return
  end
  
  -- Check if whitelist is enabled and user/chat is whitelisted
  local whitelist = redis:get('whitelist:enabled')
  if whitelist and not is_sudo(callback, config) then
	local hash = 'whitelist:user#id'..user_id
	local allowed = redis:get(hash) or false
	if not allowed then
      if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
        local allowed = redis:get('whitelist:chat#id'.. chat_id)
	    if not allowed then
	      utilities.answer_callback_query(callback, 'Du darfst den Bot nicht nutzen!', true)
		  return
	    end
	  else
	    utilities.answer_callback_query(callback, 'Du darfst den Bot nicht nutzen!', true)
		return
	  end
	end
  end

  local called_plugin = callback.data:match('(.*):.*')
  local param = callback.data:sub(callback.data:find(':')+1)

  print('Callback Query "'..param..'" für Plugin "'..called_plugin..'" ausgelöst von '..callback.from.first_name..' ('..callback.from.id..')')

  msg = utilities.enrich_message(msg)

  for n=1, #self.plugins do
    local plugin = self.plugins[n]
	if plugin.name == called_plugin then
	  if is_plugin_disabled_on_chat(plugin.name, msg) then utilities.answer_callback_query(callback, 'Plugin wurde in diesem Chat deaktiviert.') return end
      if plugin.callback then
	    plugin:callback(callback, msg, self, config, param)
        return
      else
        utilities.answer_callback_query(callback, 'Ungültiger CallbackQuery: Plugin unterstützt keine Callbacks.')
        return
      end
	end
  end
  
   utilities.answer_callback_query(callback, 'Ungültiger CallbackQuery: Kein Plugin gefunden.')
end

-- NOTE: To enable InlineQuerys, send /setinline to @BotFather
function bot:process_inline_query(inline_query, config) -- When an inline query is received
  -- remove comment to enable debugging
  -- vardump(inline_query)
  
  -- PLEASE READ: Blocking every single InlineQuery IS NOT POSSIBLE!
  -- When the request is cached, the user can still send this query
  -- but he WON'T be able to make new requests. 
  local user_id = inline_query.from.id
  if redis:get('blocked:'..user_id) then
    abort_inline_query(inline_query)
	return
  end

  if not config.enable_inline_for_everyone then
    local is_whitelisted = redis:get('whitelist:user#id'..inline_query.from.id)
    if not is_whitelisted then abort_inline_query(inline_query) return end
  end

  inline_query.query = inline_query.query:gsub('"', '\\"')
  
  if string.len(inline_query.query) > 200 then
    abort_inline_query(inline_query)
	return
  end
  
  for n=1, #self.plugins do
    local plugin = self.plugins[n]
    match_inline_plugins(self, inline_query, config, plugin)
  end
  
  -- Stop the spinning circle
  abort_inline_query(inline_query)
end

function bot:run(config)
	bot.init(self, config)

	while self.is_started do
		-- Update loop
		local res = bindings.getUpdates{ timeout = 20, offset = self.last_update+1 }
		if res then
			-- Iterate over every new message.
		    for n=1, #res.result do
			    local v = res.result[n]
				self.last_update = v.update_id
				if v.inline_query then
                    bot.process_inline_query(self, v.inline_query, config)
				elseif v.callback_query then
				    bot.on_callback_receive(self, v.callback_query, v.callback_query.message, config)
				elseif v.message then
					bot.on_msg_receive(self, v.message, config)
				end
			end
		else
			print('Connection error while fetching updates.')
		end

		-- Run cron jobs every minute.
		if self.last_cron ~= os.date('%M') then
			self.last_cron = os.date('%M')
		    for n=1, #self.plugins do 
			    local v = self.plugins[n]
				if v.cron then -- Call each plugin's cron function, if it has one.
					local result, err = pcall(function() v.cron(self, config) end)
					if not result then
						utilities.handle_exception(self, err, 'CRON: ' .. n, config.log_chat)
					end
				end
			end
		end
		if self.last_database_save ~= os.date('%H') then
			utilities.save_data(self.info.username..'.db', self.database) -- Save the database.
			self.last_database_save = os.date('%H')
		end
	end

	-- Save the database before exiting.
	utilities.save_data(self.info.username..'.db', self.database)
	print('Halted.')
end

-- Apply plugin.pre_process function
function pre_process_msg(self, msg, config)
  for n=1, #self.plugins do 
	local plugin = self.plugins[n]
	if plugin.pre_process and msg then
	  if not is_plugin_disabled_on_chat(plugin.name, msg, true) then
	    -- print('Preprocess '..plugin.name) -- remove comment to restore old behaviour
	    new_msg = plugin:pre_process(msg, config)
	    if not new_msg then return end -- Message was deleted
      end
    end
  end
  return new_msg
end

function match_inline_plugins(self, inline_query, config, plugin)
  local match_table = plugin.inline_triggers or {}
  for n=1, #match_table do 
    local trigger = plugin.inline_triggers[n]
    if string.match(string.lower(inline_query.query), trigger) then
	local success, result = pcall(function()
	  for k, pattern in pairs(plugin.inline_triggers) do
	    matches = match_pattern(pattern, inline_query.query)
		if matches then
		  break;
		end
	  end
	  print('Inline: '..plugin.name..' triggered')
	  return plugin.inline_callback(self, inline_query, config, matches)
	end)
	end
  end
end

function match_plugins(self, msg, config, plugin)
  local match_table = plugin.triggers or {}
  for n=1, #match_table do
    local trigger = plugin.triggers[n]
    if string.match(msg.text_lower, trigger) then
	-- Check if Plugin is disabled
	if is_plugin_disabled_on_chat(plugin.name, msg) then return end
	local success, result = pcall(function()
	  -- trying to port matches to otouto
	  local pattern = plugin.triggers[n]
	  local matches = match_pattern(pattern, msg.text)
	  if matches then
	    print('msg matches: ', pattern, ' for "'..plugin.name..'"')
	    return plugin.action(self, msg, config, matches)
	  end
	end)
	if not success then
	  utilities.handle_exception(self, result, msg.from.id .. ': ' .. msg.text, config.log_chat)
	  return
	end
	-- if one pattern matches, end
	return
	end
  end
end

function is_plugin_disabled_on_chat(plugin_name, msg, silent)
  local hash = get_redis_hash(msg, 'disabled_plugins')
  local disabled = redis:hget(hash, plugin_name)
  
  -- Plugin is disabled
  if disabled == 'true' then
    if not silent then
      print('Plugin '..plugin_name..' ist in diesem Chat deaktiviert')
	end
	return true
  else
    return false
  end
end

function load_plugins()
  enabled_plugins = redis:smembers('telegram:enabled_plugins')
  if not enabled_plugins[1] then
    create_plugin_set()
  end
  return enabled_plugins
end

-- create plugin set if it doesn't exist
function create_plugin_set()
  enabled_plugins = {
    'control',
    'about',
    'id',
	'post_photo',
	'images',
	'media',
	'service_migrate_to_supergroup',
	'creds',
    'echo',
	'currency',
    'banhammer',
	'plugins',
	'settings',
    'help'
  }
  print ('enabling a few plugins - saving to redis set telegram:enabled_plugins')
  for _,plugin in pairs(enabled_plugins) do
    redis:sadd("telegram:enabled_plugins", plugin)
  end
end

function load_cred()
  if redis:exists("telegram:credentials") == false then
  -- If credentials hash doesnt exists
    print ("Created new credentials hash: telegram:credentials")
    create_cred()
  end
  return redis:hgetall("telegram:credentials")
end

-- create credentials hash with redis
function create_cred()
  cred = {
  bitly_access_token = "",
  cloudinary_apikey = "",
  cloudinary_api_secret = "",
  cloudinary_public_id = "",
  derpibooru_apikey = "",
  fb_access_token = "",
  flickr_apikey = "",
  ftp_site = "",
  ftp_username = "",
  ftp_password = "",
  gender_apikey = "",
  golem_apikey = "",
  google_apikey = "",
  google_cse_id = "",
  gitlab_private_token = "",
  gitlab_project_id = "",
  instagram_access_token = "",
  lyricsnmusic_apikey = "",
  mal_username = "",
  mal_pw = "",
  neutrino_userid = "",
  neutrino_apikey = "",
  owm_apikey = "",
  page2images_restkey = "",
  soundcloud_client_id = "",
  tw_consumer_key = "",
  tw_consumer_secret = "",
  tw_access_token = "",
  tw_access_token_secret = "",
  x_mashape_key = "",
  yandex_translate_apikey = "",
  yandex_rich_content_apikey = "",
  yourls_site_url = "",
  yourls_signature_token = ""
  }
  redis:hmset("telegram:credentials", cred)
  print ('saved credentials into reds hash telegram:credentials')
end

return bot