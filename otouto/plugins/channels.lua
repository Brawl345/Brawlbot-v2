local channels = {}

local bindings = require('otouto.bindings')
local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()

channels.command = 'channel <nur für Superuser>'

function channels:init(config)
	channels.triggers = {
	"^/channel? (enable)",
	"^/channel? (disable)"
	}
	channels.doc = [[*
]]..config.cmd_pat..[[channel* _<enable>_/_<disable>_: Aktiviert/deaktiviert den Bot im Chat]]
end

-- Checks if bot was disabled on specific chat
function channels:is_channel_disabled(msg)
  local hash = 'chat:'..msg.chat.id..':disabled'
  local disabled = redis:get(hash)
  
	if not disabled or disabled == "false" then
		return false
	end

  return disabled
end

function channels:enable_channel(msg)
  local hash = 'chat:'..msg.chat.id..':disabled'
  local disabled = redis:get(hash)
  if disabled then
    print('Setting redis variable '..hash..' to false')
    redis:set(hash, false)
    return 'Channel aktiviert'
  else
    return 'Channel ist nicht deaktiviert!'
  end
end

function channels:disable_channel(msg)
  local hash = 'chat:'..msg.chat.id..':disabled'
  local disabled = redis:get(hash)
  if disabled ~= "true" then
    print('Setting redis variable '..hash..' to true')
    redis:set(hash, true)
    return 'Channel deaktiviert'
  else
    return 'Channel ist bereits deaktiviert!'
  end
end

function channels:pre_process(msg, self, config)
  -- If is sudo can reeanble the channel
  if is_sudo(msg, config) then
    if msg.text == "/channel enable" then
      channels:enable_channel(msg)
	end
  end

  if channels:is_channel_disabled(msg) then
    print('Channel wurde deaktiviert')
	msg.text = ''
	msg.text_lower = ''
	msg.entities = ''
  end

	return msg
end

function channels:action(msg, config)
  if msg.from.id ~= config.admin then
    utilities.send_reply(self, msg, config.errors.sudo)
	return
  end

  -- Enable a channel
  if matches[1] == 'enable' then
    utilities.send_reply(self, msg, channels:enable_channel(msg))
    return
  end
  -- Disable a channel
  if matches[1] == 'disable' then
    utilities.send_reply(self, msg, channels:disable_channel(msg))
    return
  end
end

return channels