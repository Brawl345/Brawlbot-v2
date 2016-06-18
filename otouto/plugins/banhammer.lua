local banhammer = {}

local bindings = require('otouto.bindings')
local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()

banhammer.command = 'banhammer <nur für Superuser>'

function banhammer:init(config)
	banhammer.triggers = {
    "^/(whitelist) (enable)$",
    "^/(whitelist) (disable)$",
    "^/(whitelist) (user) (%d+)$",
    "^/(whitelist) (chat)$",
    "^/(whitelist) (delete) (user) (%d+)$",
    "^/(whitelist) (delete) (chat)$",
    "^/(ban) (user) (%d+)$",
    "^/(ban) (delete) (%d+)$",
    "^/(kick) (%d+)$"
	}
	banhammer.doc = [[*
]]..config.cmd_pat..[[whitelist* _<enable>_/_<disable>_: Aktiviert/deaktiviert Whitelist
*]]..config.cmd_pat..[[whitelist* user _<user#id>_: Whiteliste User
*]]..config.cmd_pat..[[whitelist* chat: Whiteliste ganze Gruppe
*]]..config.cmd_pat..[[whitelist* delete user _<user#id>_: Lösche User von der Whitelist
*]]..config.cmd_pat..[[whitelist* delete chat: Lösche ganze Gruppe von der Whitelist
*]]..config.cmd_pat..[[ban* user _<user#id>_: Kicke User vom Chat und kicke ihn, wenn er erneut beitritt
*]]..config.cmd_pat..[[ban* delete _<user#id>_: Entbanne User
*]]..config.cmd_pat..[[kick* _<user#id>_: Kicke User aus dem Chat]]
end

function banhammer:kick_user(user_id, chat_id, self, onlykick)
  if user_id == tostring(our_id) then
    return "Ich werde mich nicht selbst kicken!"
  else
    local request = bindings.request(self, 'kickChatMember', {
	  chat_id = chat_id,
	  user_id = user_id
	} )
	if onlykick then return end
    if not request then return 'User gebannt, aber kicken war nicht erfolgreich. Bin ich Administrator oder ist der User hier überhaupt?' end
    return 'User '..user_id..' gebannt!'
  end
end

function banhammer:ban_user(user_id, chat_id, self)
  if user_id == tostring(our_id) then
    return "Ich werde mich nicht selbst kicken!"
  else
    -- Save to redis
    local hash =  'banned:'..chat_id..':'..user_id
    redis:set(hash, true)
    -- Kick from chat
    return banhammer:kick_user(user_id, chat_id, self)
  end
end

function banhammer:unban_user(user_id, chat_id, self, chat_type)
  local hash =  'banned:'..chat_id..':'..user_id
  redis:del(hash)
  if chat_type == 'supergroup' then -- how can bots be admins anyway?
    local request = bindings.request(self, 'unbanChatMember', {
	    chat_id = chat_id,
	    user_id = user_id
	  } )
  end
  return 'User '..user_id..' wurde entbannt.'
end

function banhammer:is_banned(user_id, chat_id)
  local hash =  'banned:'..chat_id..':'..user_id
  local banned = redis:get(hash)
  return banned or false
end

function banhammer:is_user_whitelisted(id)
  local hash = 'whitelist:user#id'..id
  local white = redis:get(hash) or false
  return white
end

function banhammer:is_chat_whitelisted(id)
  local hash = 'whitelist:chat#id'..id
  local white = redis:get(hash) or false
  return white
end

function banhammer:pre_process(msg, self, config)
  -- SERVICE MESSAGE
  if msg.new_chat_member then
	local user_id = msg.new_chat_member.id
	print('Checking invited user '..user_id)
	local banned = banhammer:is_banned(user_id, msg.chat.id)
	if banned then
      print('User is banned!')
      banhammer:kick_user(user_id, msg.chat.id, self, true)
    end
    -- No further checks
    return msg
  end
  
  -- BANNED USER TALKING
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    local user_id = msg.from.id
    local chat_id = msg.chat.id
    local banned = banhammer:is_banned(user_id, chat_id)
    if banned then
      print('Banned user talking!')
      banhammer:ban_user(user_id, chat_id, self)
      msg.text = ''
    end
  end
  

 -- WHITELIST
  local hash = 'whitelist:enabled'
  local whitelist = redis:get(hash)
  local issudo = is_sudo(msg, config)

  -- Allow all sudo users even if whitelist is allowed
  if whitelist and not issudo then
    print('Whitelist enabled and not sudo')
    -- Check if user or chat is whitelisted
    local allowed = banhammer:is_user_whitelisted(msg.from.id)
	local has_been_warned = redis:hget('user:'..msg.from.id, 'has_been_warned')

    if not allowed then
      print('User '..msg.from.id..' not whitelisted')
      if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
        allowed = banhammer:is_chat_whitelisted(msg.chat.id)
        if not allowed then
          print ('Chat '..msg.chat.id..' not whitelisted')
        else
          print ('Chat '..msg.chat.id..' whitelisted :)')
		end
      else
	    if not has_been_warned then
		  utilities.send_reply(self, msg, "Dies ist ein privater Bot, der erst nach einer Freischaltung benutzt werden kann.\nThis is a private bot, which can only be after an approval.")
		  redis:hset('user:'..msg.from.id, 'has_been_warned', true)
		else
		  print('User has already been warned!')
		end
      end
    else
      print('User '..msg.from.id..' allowed :)')
    end

    if not allowed then
      msg.text = ''
	  msg.text_lower = ''
	  msg.entities = ''
    end

 -- else 
   -- print('Whitelist not enabled or is sudo')
  end

  return msg
end

function banhammer:action(msg, config, matches)
  if msg.from.id ~= config.admin then
    utilities.send_reply(self, msg, config.errors.sudo)
	return
  end
  
  if matches[1] == 'ban' then
    local user_id = matches[3]
    local chat_id = msg.chat.id

    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
      if matches[2] == 'user' then
        local text = banhammer:ban_user(user_id, chat_id, self)
		utilities.send_reply(self, msg, text)
        return
      end
      if matches[2] == 'delete' then
		local text = banhammer:unban_user(user_id, chat_id, self, msg.chat.type)
		utilities.send_reply(self, msg, text)
        return
      end
    else
	  utilities.send_reply(self, msg, 'Das ist keine Chat-Gruppe')
      return
    end
  end
  
  if matches[1] == 'kick' then
    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
      banhammer:kick_user(matches[2], msg.chat.id, self, true)
	  return
    else
	  utilities.send_reply(self, msg, 'Das ist keine Chat-Gruppe')
      return
    end
  end
  
  if matches[1] == 'whitelist' then
    if matches[2] == 'enable' then
      local hash = 'whitelist:enabled'
      redis:set(hash, true)
      utilities.send_reply(self, msg, 'Whitelist aktiviert')
	  return
    end

    if matches[2] == 'disable' then
      local hash = 'whitelist:enabled'
      redis:del(hash)
      utilities.send_reply(self, msg, 'Whitelist deaktiviert')
	  return
    end

    if matches[2] == 'user' then
      local hash = 'whitelist:user#id'..matches[3]
      redis:set(hash, true)
      utilities.send_reply(self, msg, 'User '..matches[3]..' whitelisted')
	  return
    end

    if matches[2] == 'chat' then
      if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
	    local hash = 'whitelist:chat#id'..msg.chat.id
        redis:set(hash, true)
        utilities.send_reply(self, msg, 'Chat '..msg.chat.id..' whitelisted')
		return
      else
	    utilities.send_reply(self, msg, 'Das ist keine Chat-Gruppe!')
	    return
      end
	end

    if matches[2] == 'delete' and matches[3] == 'user' then
      local hash = 'whitelist:user#id'..matches[4]
      redis:del(hash)
      utilities.send_reply(self, msg, 'User '..matches[4]..' von der Whitelist entfernt!')
	  return
    end

    if matches[2] == 'delete' and matches[3] == 'chat' then
     if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
        local hash = 'whitelist:chat#id'..msg.chat.id
        redis:del(hash)
        utilities.send_reply(self, msg, 'Chat '..msg.chat.id..' von der Whitelist entfernt')
	    return
      else
	    utilities.send_reply(self, msg, 'Das ist keine Chat-Gruppe!')
	    return
      end
    end
  end
end

return banhammer