local id = {}

local redis = (loadfile "./otouto/redis.lua")()
local bindings = require('otouto.bindings')
local utilities = require('otouto.utilities')

id.command = 'id'

function id:init(config)
	id.triggers = {
    "^/id$",
    "^/ids? (chat)$"
	}
	id.doc = [[```
Returns user and chat info for you or the replied-to message.
Alias: ]]..config.cmd_pat..[[who
```]]
end

function id:get_member_count(self, msg, chat_id)
	return bindings.request(self, 'getChatMembersCount', {
		chat_id = chat_id
	} )
end

function id:user_print_name(user) -- Yes, copied from stats plugin
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

function id:get_user(user_id, chat_id)
  local user_info = {}
  local uhash = 'user:'..user_id
  local user = redis:hgetall(uhash)
  user_info.name = id:user_print_name(user)
  user_info.id = user_id
  return user_info
end

function id:action(msg)

  if matches[1] == "/id" then
	if msg.reply_to_message then
		msg = msg.reply_to_message
		msg.from.name = utilities.build_name(msg.from.first_name, msg.from.last_name)
	end

	local chat_id = msg.chat.id
	local user = 'Du bist @%s, auch bekannt als *%s* `[%s]`'
	if msg.from.username then
		user = user:format(utilities.markdown_escape(msg.from.username), msg.from.name, msg.from.id)
	else
		user = 'Du bist *%s* `[%s]`,'
		user = user:format(msg.from.name, msg.from.id)
	end

	local group = '@%s, auch bekannt als *%s* `[%s]`.'
	if msg.chat.type == 'private' then
		group = group:format(utilities.markdown_escape(self.info.username), self.info.first_name, self.info.id)
	elseif msg.chat.username then
		group = group:format(utilities.markdown_escape(msg.chat.username), msg.chat.title, chat_id)
	else
		group = '*%s* `[%s]`.'
		group = group:format(msg.chat.title, chat_id)
	end

	local output = user .. ', und du bist in der Gruppe ' .. group

	utilities.send_message(self, msg.chat.id, output, true, msg.message_id, true)
  elseif matches[1] == "chat" then
    if msg.chat.type ~= 'group' and msg.chat.type ~= 'supergroup' then
	  utilities.send_reply(self, msg, 'Das hier ist keine Gruppe!')
	  return
	end
    local chat_name = msg.chat.title
	local chat_id = msg.chat.id
	-- Users on chat
    local hash = 'chat:'..chat_id..':users'
    local users = redis:smembers(hash)
    local users_info = {}
	  -- Get user info
	for i = 1, #users do
      local user_id = users[i]
      local user_info = id:get_user(user_id, chat_id)
      table.insert(users_info, user_info)
    end
	local result = id:get_member_count(self, msg, chat_id)
	local member_count = result.result - 1 -- minus the bot
	if member_count == 1 then
	  member_count = 'ist *1 Mitglied'
	else
	  member_count = 'sind *'..member_count..' Mitglieder'
	end
    local text = 'IDs für *'..chat_name..'* `['..chat_id..']`\nHier '..member_count..':*\n---------\n'
    for k,user in pairs(users_info) do
      text = text..'*'..user.name..'* `['..user.id..']`\n'
	  text = string.gsub(text, "%_", " ")
    end
	utilities.send_reply(self, msg, text, true)
  end
end

return id
