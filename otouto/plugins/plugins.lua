local plugin_manager = {}

local bot = require('otouto.bot')

function plugin_manager:init(config)
	plugin_manager.triggers = {
    "^/plugins$",
    "^/plugins? (enable) ([%w_%.%-]+) (chat) (%d+)$",
    "^/plugins? (enable) ([%w_%.%-]+) (chat)$",
	"^/plugins? (disable) ([%w_%.%-]+) (chat) (%d+)$",
	"^/plugins? (disable) ([%w_%.%-]+) (chat)$",
    "^/plugins? (enable) ([%w_%.%-]+)$",
    "^/plugins? (disable) ([%w_%.%-]+)$",
    "^/plugins? (reload)$",
	"^/(reload)$"
	}
	plugin_manager.doc = [[*
]]..config.cmd_pat..[[plugins*: Listet alle Plugins auf
*]]..config.cmd_pat..[[plugins* _enable/disable_ _<Plugin>_: Aktiviert/deaktiviert Plugin
*]]..config.cmd_pat..[[plugins* _enable/disable_ _<Plugin>_ chat: Aktiviert/deaktiviert Plugin im aktuellen Chat
*]]..config.cmd_pat..[[plugins* _enable/disable_ _<Plugin>_ _<chat#id>_: Aktiviert/deaktiviert Plugin in diesem Chat
*]]..config.cmd_pat..[[reload*: Lädt Plugins neu]]
end

plugin_manager.command = 'plugins <nur für Superuser>'

-- Returns the key (index) in the config.enabled_plugins table
function plugin_manager:plugin_enabled(name, chat)
  for k,v in pairs(enabled_plugins) do
    if name == v then
      return k
    end
  end
  -- If not found
  return false
end

-- Returns true if file exists in plugins folder
function plugin_manager:plugin_exists(name)
  for k,v in pairs(plugins_names()) do
    if name..'.lua' == v then
      return true
    end
  end
  return false
end

function plugin_manager:list_plugins()
  local text = ''
  for k, v in pairs(plugins_names()) do
    --  ✔ enabled, ❌ disabled
    local status = '❌'
    -- Check if is enabled
    for k2, v2 in pairs(enabled_plugins) do
      if v == v2..'.lua' then 
        status = '✔' 
      end
    end
    if not only_enabled or status == '✔' then
      -- get the name
      v = string.match (v, "(.*)%.lua")
      text = text..v..'  '..status..'\n'
    end
  end
  return text
end

function plugin_manager:reload_plugins(self, config, plugin_name, status)
		for pac, _ in pairs(package.loaded) do
			if pac:match('^otouto%.plugins%.') then
				package.loaded[pac] = nil
			end
		end
		package.loaded['otouto.bindings'] = nil
		package.loaded['otouto.utilities'] = nil
		package.loaded['config'] = nil
		bot.init(self, config)
  if plugin_name then
    return 'Plugin '..plugin_name..' wurde '..status
  else
    return 'Plugins neu geladen'
  end
end

function plugin_manager:enable_plugin(self, config, plugin_name)
  print('checking if '..plugin_name..' exists')
  -- Check if plugin is enabled
  if plugin_manager:plugin_enabled(plugin_name) then
    return 'Plugin '..plugin_name..' ist schon aktiviert'
  end
  -- Checks if plugin exists
  if plugin_manager:plugin_exists(plugin_name) then
    -- Add to redis set
    redis:sadd('telegram:enabled_plugins', plugin_name)
	print(plugin_name..' saved to redis set telegram:enabled_plugins')
    -- Reload the plugins
    return plugin_manager:reload_plugins(self, config, plugin_name, 'aktiviert')
  else
    return 'Plugin '..plugin_name..' existiert nicht'
  end
end

function plugin_manager:disable_plugin(self, config, name, chat)
  -- Check if plugins exists
  if not plugin_manager:plugin_exists(name) then
    return 'Plugin '..name..' existiert nicht'
  end
  local k = plugin_manager:plugin_enabled(name)
  -- Check if plugin is enabled
  if not k then
    return 'Plugin '..name..' ist nicht aktiviert'
  end
  -- Disable and reload
    redis:srem('telegram:enabled_plugins', name)
	print(name..' saved to redis set telegram:enabled_plugins')
   return plugin_manager:reload_plugins(self, config, name, 'deaktiviert')    
end

function plugin_manager:disable_plugin_on_chat(msg, plugin)
  if not plugin_manager:plugin_exists(plugin) then
    return "Plugin existiert nicht!"
  end
  
  if not msg.chat then
    hash = 'chat:'..msg..':disabled_plugins'
  else
    hash = get_redis_hash(msg, 'disabled_plugins')
  end
  local disabled = redis:hget(hash, plugin)

  if disabled ~= 'true' then
    print('Setting '..plugin..' in redis hash '..hash..' to true')
    redis:hset(hash, plugin, true)
	return 'Plugin '..plugin..' für diesen Chat deaktiviert.'
  else
    return 'Plugin '..plugin..' wurde für diesen Chat bereits deaktiviert.'
  end
end

function plugin_manager:reenable_plugin_on_chat(msg, plugin)
  if not plugin_manager:plugin_exists(plugin) then
    return "Plugin existiert nicht!"
  end
  
  if not msg.chat then
    hash = 'chat:'..msg..':disabled_plugins'
  else
    hash = get_redis_hash(msg, 'disabled_plugins')
  end
  local disabled = redis:hget(hash, plugin)
  
  if disabled == nil then return 'Es gibt keine deaktivierten Plugins für disen Chat.' end

  if disabled == 'true' then
    print('Setting '..plugin..' in redis hash '..hash..' to false')
    redis:hset(hash, plugin, false)
	return 'Plugin '..plugin..' wurde für diesen Chat reaktiviert.'
  else
    return 'Plugin '..plugin..' ist nicht deaktiviert.'
  end
end

function plugin_manager:action(msg, config, matches)
  if msg.from.id ~= config.admin then
    utilities.send_reply(msg, config.errors.sudo)
	return
  end

  -- Show the available plugins 
  if matches[1] == '/plugins' then
    utilities.send_reply(msg, plugin_manager:list_plugins())
    return
  end
  
  -- Reenable a plugin for this chat
  if matches[1] == 'enable' and matches[3] == 'chat' then
    local plugin = matches[2]
	if matches[4] then 
	  local id = matches[4]
      print("enable "..plugin..' on chat#id'..id)
	  utilities.send_reply(msg, plugin_manager:reenable_plugin_on_chat(id, plugin))
      return
	else
      print("enable "..plugin..' on this chat')
	  utilities.send_reply(msg, plugin_manager:reenable_plugin_on_chat(msg, plugin))
      return
    end
  end
  
  -- Enable a plugin
  if matches[1] == 'enable' then
    local plugin_name = matches[2]
    print("enable: "..matches[2])
	utilities.send_reply(msg, plugin_manager:enable_plugin(self, config, plugin_name))
    return
  end
  
  -- Disable a plugin on a chat
  if matches[1] == 'disable' and matches[3] == 'chat' then
    local plugin = matches[2]
	if matches[4] then 
	  local id = matches[4]
      print("disable "..plugin..' on chat#id'..id)
	  utilities.send_reply(msg, plugin_manager:disable_plugin_on_chat(id, plugin))
      return
	else
      print("disable "..plugin..' on this chat')
	  utilities.send_reply(msg, plugin_manager:disable_plugin_on_chat(msg, plugin))
      return
    end
  end
  
  -- Disable a plugin
  if matches[1] == 'disable' then
    print("disable: "..matches[2])
	utilities.send_reply(msg, plugin_manager:disable_plugin(self, config, matches[2]))
    return
  end

  -- Reload all the plugins!
  if matches[1] == 'reload' then
    utilities.send_reply(msg, plugin_manager:reload_plugins(self, config))
    return
  end
end

return plugin_manager