local stats = {}

local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()

function stats:init(config)
	stats.triggers = {
    "^/([Ss]tats)$",
	"^/([Ss]tats) (chat) (%-%d+)",
    "^/([Ss]tats) (chat) (%d+)"
	}
	stats.doc = [[*
]]..config.cmd_pat..[[stats*: Zeigt Stats an
*]]..config.cmd_pat..[[stats* _chat_ _<chat#id>_: Stats für Chat-ID (nur Superuser)
]]
end

stats.command = 'stats'

function stats:user_print_name(user)
  if user.name then
    return user.name
  end

  local text = ''
  if user.first_name then
    text = user.last_name..' '
  end
  if user.lastname then
    text = text..user.last_name
  end

  return text
end

-- Returns a table with `name` and `msgs`
function stats:get_msgs_user_chat(user_id, chat_id)
  local user_info = {}
  local uhash = 'user:'..user_id
  local user = redis:hgetall(uhash)
  local um_hash = 'msgs:'..user_id..':'..chat_id
  user_info.msgs = tonumber(redis:get(um_hash) or 0)
  user_info.name = stats:user_print_name(user)
  return user_info
end

function stats:chat_stats(chat_id)
  -- Users on chat
  local hash = 'chat:'..chat_id..':users'
  local users = redis:smembers(hash)
  local users_info = {}

  -- Get user info
  for i = 1, #users do
    local user_id = users[i]
    local user_info = stats:get_msgs_user_chat(user_id, chat_id)
    table.insert(users_info, user_info)
  end

  -- Sort users by msgs number
  table.sort(users_info, function(a, b) 
      if a.msgs and b.msgs then
        return a.msgs > b.msgs
      end
    end)

  local text = ''
  for k,user in pairs(users_info) do
    text = text..user.name..': '..user.msgs..'\n'
	text = string.gsub(text, "%_", " ") -- Bot API doesn't use underscores anymore! Yippie!
  end
  if text:isempty() then return 'Keine Stats für diesen Chat verfügbar!'end
  return text
end

function stats:pre_process(msg, self)
  -- Ignore service msg
  if msg.service then -- check how Bot API handles service msgs, will update this
    print('Service message')
    return
  end

  -- Save user on Redis
  local hash = 'user:'..msg.from.id
  -- print('Saving user', hash) -- remove comment to restore old behaviour
  if msg.from.name then
    redis:hset(hash, 'name', msg.from.name)
  end
  if msg.from.first_name then
	redis:hset(hash, 'first_name', msg.from.first_name)
  end
  if msg.from.last_name then
	redis:hset(hash, 'last_name', msg.from.last_name)
  end

  -- Save stats on Redis
  if msg.chat.type ~= 'private' then
    -- User is on chat
    local hash = 'chat:'..msg.chat.id..':users'
    redis:sadd(hash, msg.from.id)
  end

  -- Total user msgs
  local hash = 'msgs:'..msg.from.id..':'..msg.chat.id
  redis:incr(hash)
  return
end

function stats:action(msg, config, matches)
  if matches[1]:lower() == "stats" then

    if not matches[2] then
      if msg.chat.type == 'private' then
	    utilities.send_reply(self, msg, 'Stats funktionieren nur in Chats!')
        return
      else
        local chat_id = msg.chat.id
		utilities.send_reply(self, msg, stats:chat_stats(chat_id))
        return
      end
    end

    if matches[2] == "chat" then
	  if msg.from.id ~= config.admin then
        utilities.send_reply(self, msg, config.errors.sudo)
	    return
      else
	    utilities.send_reply(self, msg, stats:chat_stats(matches[3]))
        return
      end
    end
  end
end

return stats