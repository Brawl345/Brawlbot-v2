-- original plugin by Akamaru [https://ponywave.de]
-- I added Redis and automatic online switching back in 2015

local afk = {}

function afk:init(config)
	afk.triggers = {
      "^/([A|a][F|f][K|k]) (.*)$",
	  "^/([A|a][F|f][K|k])$"
	}
	afk.doc = [[*
]]..config.cmd_pat..[[afk* _[Text]_: Setzt Status auf AFK mit optionalem Text]]
end

afk.command = 'afk [Text]'

function afk:is_offline(hash)
  local afk = redis:hget(hash, 'afk')
  if afk == "true" then
    return true
  else
    return false
  end
end

function afk:get_afk_text(hash)
  local afk_text = redis:hget(hash, 'afk_text')
  if afk_text ~= nil and afk_text ~= "" and afk_text ~= "false" then
    return afk_text
  else
    return false
  end
end

function afk:switch_afk(user_name, user_id, chat_id, timestamp, text)
  local hash =  'afk:'..chat_id..':'..user_id
  
  if afk:is_offline(hash) then
    local afk_text = afk:get_afk_text(hash)
    if afk_text then
      return 'Du bist bereits AFK ('..afk_text..')!'
	else
	  return 'Du bist bereits AFK!'
	end
  end
  
  print('Setting redis hash afk in '..hash..' to true')
  redis:hset(hash, 'afk', true)
  print('Setting redis hash timestamp in '..hash..' to '..timestamp)
  redis:hset(hash, 'time', timestamp)
  
  if text then
    print('Setting redis hash afk_text in '..hash..' to '..text)
    redis:hset(hash, 'afk_text', text)
    return user_name..' ist AFK ('..text..')'
  else
    return user_name..' ist AFK'
  end
end

function afk:pre_process(msg, self)
  if msg.chat.type == "private" then
	-- Ignore
    return
  end

  local user_name = get_name(msg)
  local user_id = msg.from.id
  local chat_id = msg.chat.id
  local hash =  'afk:'..chat_id..':'..user_id
  local uhash = 'user:'..user_id
  
  if afk:is_offline(hash) then
    local afk_text = afk:get_afk_text(hash)
	
	-- calculate afk time
	local timestamp = redis:hget(hash, 'time')
	local current_timestamp = msg.date
	local afk_time = current_timestamp - timestamp
    local duration = makeHumanTime(afk_time)
   
	redis:hset(hash, 'afk', false)
	local show_afk_keyboard = redis:hget(uhash, 'afk_keyboard')
    if afk_text then
	  redis:hset(hash, 'afk_text', false)
	  if show_afk_keyboard == 'true' then
	    utilities.send_reply(self, msg, user_name..' ist wieder da (war: <b>'..afk_text..'</b> für '..duration..')!', 'HTML', '{"hide_keyboard":true,"selective":true}')
	 else
	   utilities.send_message(self, chat_id, user_name..' ist wieder da (war: <b>'..afk_text..'</b> für '..duration..')!', true, nil, 'HTML')
	 end
	else
	  if show_afk_keyboard == 'true' then
	    utilities.send_reply(self, msg, user_name..' ist wieder da (war '..duration..' weg)!', nil, '{"hide_keyboard":true,"selective":true}')
	  else
	    utilities.send_message(self, chat_id, user_name..' ist wieder da (war '..duration..' weg)!')
	  end
	end
  end
  
  return msg
end

function afk:action(msg, config, matches)
  if msg.chat.type == "private" then
    utilities.send_reply(self, msg, "Mir ist's egal, ob du AFK bist ._.")
    return
  end
  
  local user_id = msg.from.id
  local chat_id = msg.chat.id
  local user_name = get_name(msg)
  local timestamp = msg.date
  local uhash = 'user:'..msg.from.id
  local show_afk_keyboard = redis:hget(uhash, 'afk_keyboard')
  if show_afk_keyboard == 'true' then
    keyboard = '{"keyboard":[[{"text":"Wieder da."}]], "one_time_keyboard":true, "selective":true, "resize_keyboard":true}'
  else
    keyboard = nil
  end
  
  utilities.send_reply(self, msg, afk:switch_afk(user_name, user_id, chat_id, timestamp, matches[2]), false, keyboard)
end

return afk