local bot = {}

bindings = require('otouto.bindings')
utilities = require('otouto.utilities')

bot.version = '2.2.5.1c'

function bot:init(config) -- The function run when the bot is started or reloaded.
	cred_data = load_cred()

	assert(
		config.bot_api_key and config.bot_api_key ~= '',
    'You did not set your bot token in the config!'
	)
	self.BASE_URL = 'https://api.telegram.org/bot' .. config.bot_api_key .. '/'

	-- Fetch bot information. Try until it succeeds.
	repeat
		print('Fetching bot information...')
		self.info = bindings.getMe(self)
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

	self.last_update = self.last_update or 0 -- Set loop variables: Update offset,
	self.last_cron = self.last_cron or os.date('%M') -- the time of the last cron job,
	self.last_database_save = self.last_database_save or os.date('%H') -- the time of the last database save,
	self.is_started = true -- and whether or not the bot should be running.

end

function bot:on_msg_receive(msg, config) -- The fn run whenever a message is received.
	-- remove comment to enable debugging
    -- vardump(msg)
	-- Cache user info for those involved.
	
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
	
	if is_service_msg(msg) then
	  msg = service_modify_msg(msg)
	end

  for n=1, #self.plugins do
    local plugin = self.plugins[n]
	match_plugins(self, msg, config, plugin)
  end
end

function bot:on_callback_receive(callback, msg, config) -- whenever a new callback is received
  -- remove comments to enable debugging
  -- vardump(msg)
  -- vardump(callback)

  if msg.date < os.time() - 1800 then -- Do not process old messages.
    utilities.answer_callback_query(self, callback, 'Nachricht älter als eine halbe Stunde, bitte sende den Befehl selbst noch einmal.', true)
    return
  end

  if not callback.data:find(':') or not callback.data:find('@'..self.info.username..' ') then
	return
  end
  callback.data = string.gsub(callback.data, '@'..self.info.username..' ', "")
  local called_plugin = callback.data:match('(.*):.*')
  local param = callback.data:sub(callback.data:find(':')+1)

  print('Callback Query "'..param..'" für Plugin "'..called_plugin..'" ausgelöst von '..callback.from.first_name..' ('..callback.from.id..')')

  msg = utilities.enrich_message(msg)

  for n=1, #self.plugins do
    local plugin = self.plugins[n]
	if plugin.name == called_plugin then
	  if is_plugin_disabled_on_chat(plugin.name, msg) then return end
	  plugin:callback(callback, msg, self, config, param)
	end
  end
end

-- NOTE: To enable InlineQuerys, send /setinline to @BotFather
function bot:process_inline_query(inline_query, config) -- When an inline query is received
  -- remove comment to enable debugging
  -- vardump(inline_query)

  if not config.enable_inline_for_everyone then
    local is_whitelisted = redis:get('whitelist:user#id'..inline_query.from.id)
    if not is_whitelisted then utilities.answer_inline_query(self, inline_query) return end
  end

  if inline_query.query:match('"') then
    inline_query.query = inline_query.query:gsub('"', '\\"')
  end
  
  for n=1, #self.plugins do
    local plugin = self.plugins[n]
    match_inline_plugins(self, inline_query, config, plugin)
  end
end

function bot:run(config)
	bot.init(self, config) -- Actually start the script.

	while self.is_started do -- Start a loop while the bot should be running.
		local res = bindings.getUpdates(self, { timeout=20, offset = self.last_update+1 } )
		if res then
		    for n=1, #res.result do  -- Go through every new message.
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

		if self.last_cron ~= os.date('%M') then -- Run cron jobs every minute.
			self.last_cron = os.date('%M')
			utilities.save_data(self.info.username..'.db', self.database) -- Save the database.
		    for n=1, #self.plugins do 
			    local v = self.plugins[n]
				if v.cron then -- Call each plugin's cron function, if it has one.
					local result, err = pcall(function() v.cron(self, config) end)
					if not result then
						utilities.handle_exception(self, err, 'CRON: ' .. i, config)
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
	  -- print('Preprocess '..plugin.name) -- remove comment to restore old behaviour
	  new_msg = plugin:pre_process(msg, self, config)
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
	if not success then
	  print(result)
	end
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
	  print(plugin.name..' triggered')
	  return plugin.action(self, msg, config, matches)
	end)
	if not success then
	-- If the plugin has an error message, send it. If it does
	-- not, use the generic one specified in config. If it's set
	-- to false, do nothing.
	if plugin.error then
	  utilities.send_reply(self, msg, plugin.error)
	elseif plugin.error == nil then
	  utilities.send_reply(self, msg, config.errors.generic, true)
	end
	utilities.handle_exception(self, result, msg.from.id .. ': ' .. msg.text, config)
	return
	end
	end
  end
end

function is_plugin_disabled_on_chat(plugin_name, msg)
  local hash = get_redis_hash(msg, 'disabled_plugins')
  local disabled = redis:hget(hash, plugin_name)
  
  -- Plugin is disabled
  if disabled == 'true' then
    print('Plugin '..plugin_name..' ist in diesem Chat deaktiviert')
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
    'echo',
    'banhammer',
    'channels',
	'plugins',
    'help',
    'greetings'
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