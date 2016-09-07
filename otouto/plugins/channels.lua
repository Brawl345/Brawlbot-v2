local channels = {}

channels.command = 'channel <nur für Superuser>'

function channels:init(config)
	channels.triggers = {
	"^/channel? (enable)",
	"^/channel? (disable)"
	}
	channels.doc = [[*
]]..config.cmd_pat..[[channel* _<enable>_/_<disable>_: Aktiviert/deaktiviert den Bot im Chat]]
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

function channels:pre_process(msg, config)
  -- If is sudo can reeanble the channel
  if is_sudo(msg, config) then
    if msg.text == "/channel enable" then
      channels:enable_channel(msg)
	end
  end

  return msg
end

function channels:action(msg, config, matches)
  if not is_sudo(msg, config) then
    utilities.send_reply(msg, config.errors.sudo)
	return
  end

  -- Enable a channel
  if matches[1] == 'enable' then
    utilities.send_reply(msg, channels:enable_channel(msg))
    return
  end
  -- Disable a channel
  if matches[1] == 'disable' then
    utilities.send_reply(msg, channels:disable_channel(msg))
    return
  end
end

return channels