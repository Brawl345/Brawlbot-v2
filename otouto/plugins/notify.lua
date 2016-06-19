-- INFO: Stats must be activated, so that it can collect all members of a group and save his/her id to redis.
-- You can deactivate it afterwards.

local notify = {}

local redis = (loadfile "./otouto/redis.lua")()
local utilities = require('otouto.utilities')

function notify:init(config)
  notify.triggers = {
    "^/notify (del)$",
    "^/notify$"
  }
  
	notify.doc = [[*
]]..config.cmd_pat..[[notify* (del): Benachrichtigt dich privat, wenn du erwähnt wirst (bzw. schaltet das Feature wieder aus)]]
end

notify.command = 'notify [del]'

-- See https://stackoverflow.com/a/32854917
function isWordFoundInString(word,input)
  return select(2,input:gsub('^' .. word .. '%W+','')) +
         select(2,input:gsub('%W+' .. word .. '$','')) +
         select(2,input:gsub('^' .. word .. '$','')) +
         select(2,input:gsub('%W+' .. word .. '%W+','')) > 0
end

function notify:pre_process(msg, self)
  local notify_users = redis:smembers('notify:ls')
  
  -- I call this beautiful lady the "if soup"
  if msg.chat.type == 'chat' or msg.chat.type == 'supergroup' then
    if msg.text then
      for _,user in pairs(notify_users) do
	    if isWordFoundInString('@'..user, string.lower(msg.text)) then
		  local chat_id = msg.chat.id
		  local id = redis:hget('notify:'..user, 'id')
		  -- check, if user has sent at least one message to the group,
		  -- so that we don't send the user some private text, when he/she is not
		  -- in the group.
		  if redis:sismember('chat:'..chat_id..':users', id) then
		  
		    -- ignore message, if user is mentioning him/herself
		    if id == tostring(msg.from.id) then break; end

	        local send_date = run_command('date -d @'..msg.date..' +"%d.%m.%Y um %H:%M:%S Uhr"')
			local send_date = string.gsub(send_date, "\n", "")
		    local from = string.gsub(msg.from.name, "%_", " ")
			local chat_name = string.gsub(msg.chat.title, "%_", " ")
		    local text = from..' am '..send_date..' in "'..chat_name..'":\n\n'..msg.text
			utilities.send_message(self, id, text)
		  end
	    end
	  end
	end
  end

  return msg
end

function notify:action(msg, config, matches)
  if not msg.from.username then
    return 'Du hast keinen Usernamen und kannst daher dieses Feature nicht nutzen. Tut mir leid!' 
  end
  
  local username = string.lower(msg.from.username)
  
  local hash = 'notify:'..username
  
  if matches[1] == "del" then
    if not redis:sismember('notify:ls', username) then
	  utilities.send_reply(self, msg, 'Du wirst noch gar nicht benachrichtigt!')
	  return
	end
    print('Setting notify in redis hash '..hash..' to false')
    redis:hset(hash, 'notify', false)
    print('Removing '..username..' from redis set notify:ls')
    redis:srem('notify:ls', username)
	utilities.send_reply(self, msg, 'Du erhälst jetzt keine Benachrichtigungen mehr, wenn du angesprochen wirst.')
	return
  else
    if redis:sismember('notify:ls', username) then
	  utilities.send_reply(self, msg, 'Du wirst schon benachrichtigt!')
	  return
	end
    print('Setting notify in redis hash '..hash..' to true')
    redis:hset(hash, 'notify', true)
    print('Setting id in redis hash '..hash..' to '..msg.from.id)
    redis:hset(hash, 'id', msg.from.id)
    print('Adding '..username..' to redis set notify:ls')
    redis:sadd('notify:ls', username)
	local res = utilities.send_message(self, msg.from.id, 'Du erhälst jetzt Benachrichtigungen, wenn du angesprochen wirst, nutze `/notify del` zum Deaktivieren.', true, nil, true)
	if not res then
	  utilities.send_reply(self, msg, 'Bitte schreibe mir [privat](http://telegram.me/' .. self.info.username .. '?start=about), um den Vorgang abzuschließen.', true)
	elseif msg.chat.type ~= 'private' then
	  utilities.send_reply(self, msg, 'Du erhälst jetzt Benachrichtigungen, wenn du angesprochen wirst, nutze `/notify del` zum Deaktivieren.', true)
	end
  end
end

return notify