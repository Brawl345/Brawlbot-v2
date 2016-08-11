local banhammer = {}

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
	"^/(block) (user) (%d+)$",
	"^/(block) (delete) (%d+)$",
	"^/(whitelist)$",
	"^/(whitelist) (delete)$",
	"^/(ban)$",
	"^/(ban) (delete)$",
	"^/(block)$",
	"^/(block) (delete)$",
    "^/(kick) (%d+)$",
	"^/(kick)$",
	"^/(leave)$"
	}
	banhammer.doc = [[*
]]..config.cmd_pat..[[whitelist* _<enable>_/_<disable>_: Aktiviert/deaktiviert Whitelist
*]]..config.cmd_pat..[[whitelist* user _<user#id>_: Whiteliste User
*]]..config.cmd_pat..[[whitelist* chat: Whiteliste ganze Gruppe
*]]..config.cmd_pat..[[whitelist* delete user _<user#id>_: Lösche User von der Whitelist
*]]..config.cmd_pat..[[whitelist* delete chat: Lösche ganze Gruppe von der Whitelist
*]]..config.cmd_pat..[[ban* user _<user#id>_: Kicke User vom Chat und kicke ihn, wenn er erneut beitritt
*]]..config.cmd_pat..[[ban* delete _<user#id>_: Entbanne User
*]]..config.cmd_pat..[[block* user _<user#id>_: Blocke User vom Bot
*]]..config.cmd_pat..[[block* delete _<user#id>_: Entblocke User
*]]..config.cmd_pat..[[kick* _<user#id>_: Kicke User aus dem Chat
*]]..config.cmd_pat..[[leave*: Bot verlässt die Gruppe

Alternativ kann auch auf die Nachricht des Users geantwortet werden, die Befehle sind dnn die obrigen ohne `user` bzw.`delete`.]]
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
  if chat_type == 'supergroup' then
    bindings.request(self, 'unbanChatMember', {
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
  local user_id = msg.from.id
  local chat_id = msg.chat.id
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    local banned = banhammer:is_banned(user_id, chat_id)
    if banned then
      print('Banned user talking!')
      banhammer:ban_user(user_id, chat_id, self)
      return
    end
  end
  
  -- BLOCKED USER TALKING (block = user can't use bot, but won't be kicked from group)
  local hash = 'blocked:'..user_id
  local issudo = is_sudo(msg, config)
  local blocked = redis:get(hash)
  if blocked and not issudo then
    print('User '..user_id..' blocked')
	return
  end

  -- WHITELIST
  local hash = 'whitelist:enabled'
  local whitelist = redis:get(hash)

  -- Allow all sudo users even if whitelist is allowed
  if whitelist and not issudo then
    print('Whitelist enabled and not sudo')
    -- Check if user or chat is whitelisted
    local allowed = banhammer:is_user_whitelisted(user_id)
	local has_been_warned = redis:hget('user:'..user_id, 'has_been_warned')

    if not allowed then
      print('User '..user_id..' not whitelisted')
      if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
        allowed = banhammer:is_chat_whitelisted(chat_id)
        if not allowed then
          print ('Chat '..chat_id..' not whitelisted')
        else
          print ('Chat '..chat_id..' whitelisted :)')
		end
      else
	    if not has_been_warned then
		  utilities.send_reply(self, msg, "Dies ist ein privater Bot, der erst nach einer Freischaltung benutzt werden kann.\nThis is a private bot, which can only be after an approval.")
		  redis:hset('user:'..user_id, 'has_been_warned', true)
		else
		  print('User has already been warned!')
		end
      end
    else
      print('User '..user_id..' allowed :)')
    end

    if not allowed then
      return
    end

  end

  return msg
end

function banhammer:action(msg, config, matches)
  if not is_sudo(msg, config) then
    utilities.send_reply(self, msg, config.errors.sudo)
	return
  end
  
  if matches[1] == 'leave' then
    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
	  bindings.request(self, 'leaveChat', {
	    chat_id = msg.chat.id
	  } )
	  return
	end
  end
  
  if matches[1] == 'ban' then
    local user_id = matches[3]
    local chat_id = msg.chat.id
	if not user_id then
	  if not msg.reply_to_message then
	    return
	  end
	  user_id = msg.reply_to_message.from.id
	end

    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
      if matches[2] == 'user' or not matches[2] then
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
	  local user_id = matches[2]
	  if not user_id then
		if not msg.reply_to_message then
		  return
		end
		user_id = msg.reply_to_message.from.id
	  end
      banhammer:kick_user(user_id, msg.chat.id, self, true)
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
	
	if not matches[2] then
	  if not msg.reply_to_message then
		return
	  end
	  local user_id = msg.reply_to_message.from.id
	  local hash = 'whitelist:user#id'..user_id
	  redis:set(hash, true)
      utilities.send_reply(self, msg, 'User '..user_id..' whitelisted')
	  return
	end
	
	if matches[2] == 'delete' and not matches[3] then
	  if not msg.reply_to_message then
		return
	  end
	  local user_id = msg.reply_to_message.from.id
	  local hash = 'whitelist:user#id'..user_id
      redis:del(hash)
      utilities.send_reply(self, msg, 'User '..user_id..' von der Whitelist entfernt!')
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

  if matches[1] == 'block' then
    
	if matches[2] == 'user' and matches[3] then
	  local hash = 'blocked:'..matches[3]
	  redis:set(hash, true)
	  utilities.send_reply(self, msg, 'User '..matches[3]..' darf den Bot nun nicht mehr nutzen.')
	  return
	end
	
	if matches[2] == 'delete' and matches[3] then
	  local hash = 'blocked:'..matches[3]
	  redis:del(hash)
	  utilities.send_reply(self, msg, 'User '..matches[3]..' darf den Bot wieder nutzen.')
	  return
	end
	
	if not matches[2] then
	  if not msg.reply_to_message then
		return
	  end
	  local user_id = msg.reply_to_message.from.id
	  local hash = 'blocked:'..user_id
	  redis:set(hash, true)
	  utilities.send_reply(self, msg, 'User '..user_id..' darf den Bot nun nicht mehr nutzen.')
	  return
	end
	
	if matches[2] == 'delete' and not matches[3] then
	  if not msg.reply_to_message then
		return
	  end
	  local user_id = msg.reply_to_message.from.id
	  local hash = 'blocked:'..user_id
	  redis:del(hash)
	  utilities.send_reply(self, msg, 'User '..user_id..' darf den Bot wieder nutzen.')
	  return
	end
	
  end
end

return banhammer