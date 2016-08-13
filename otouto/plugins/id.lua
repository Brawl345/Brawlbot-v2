local id = {}

id.command = 'id'

function id:init(config)
  id.triggers = {
    "^/id$",
    "^/ids? (chat)$"
  }

  id.inline_triggers = {
	"^id$"
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

function id:inline_callback(inline_query, config, matches)
  local id = tostring(inline_query.from.id)
  local name = utilities.build_name(inline_query.from.first_name, inline_query.from.last_name)
  
  local results = '[{"type":"article","id":"30","title":"Deine Telegram-ID ist:","description":"'..id..'","input_message_content":{"message_text":"<b>'..name..'</b>: <code>'..id..'</code>","parse_mode":"HTML"}}]'
  utilities.answer_inline_query(self, inline_query, results, 10000, true)
end

function id:action(msg, config, matches)

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
	  users_info[#users_info+1] = user_info
    end

	-- get all administrators and the creator
	local administrators = utilities.get_chat_administrators(self, chat_id)
	local admins = {}
	for num in pairs(administrators.result) do
	  if administrators.result[num].status ~= 'creator' then
	    admins[#admins+1] = tostring(administrators.result[num].user.id)
	  else
	    creator_id = administrators.result[num].user.id
	  end
    end
	local result = id:get_member_count(self, msg, chat_id)
	local member_count = result.result
	if member_count == 1 then
	  member_count = 'ist *1 Mitglied'
	else
	  member_count = 'sind *'..member_count..' Mitglieder'
	end
    local text = 'IDs für *'..chat_name..'* `['..chat_id..']`\nHier '..member_count..':*\n---------\n'
    for k,user in pairs(users_info) do
	  if table.contains(admins, tostring(user.id)) then
	    text = text..'*'..user.name..'* `['..user.id..']` _Administrator_\n'
	  elseif tostring(creator_id) == user.id then
	    text = text..'*'..user.name..'* `['..user.id..']` _Gründer_\n'
	  else
        text = text..'*'..user.name..'* `['..user.id..']`\n'
	  end
    end
	utilities.send_reply(self, msg, text..'_(Bots sind nicht gelistet)_', true)
  end
end

return id
