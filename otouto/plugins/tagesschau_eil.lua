local tagesschau_eil = {}

tagesschau_eil.command = 'eil <sub/del>'

function tagesschau_eil:init(config)
	tagesschau_eil.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('eil', true).table
	tagesschau_eil.doc = [[*
]]..config.cmd_pat..[[eil* _sub_: Eilmeldungen abonnieren
*]]..config.cmd_pat..[[eil* _del_: Eilmeldungen deabonnieren
*]]..config.cmd_pat..[[eil* _sync_: Nach neuen Eilmeldungen prüfen (nur Superuser)]]
end

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+)%:(%d+)%:(%d+)"
  local year, month, day, hours, minutes, seconds = dateString:match(pattern)
  return day..'.'..month..'.'..year..' um '..hours..':'..minutes..':'..seconds
end

local url = 'http://www.tagesschau.de/api'
local hash = 'telegram:tagesschau'

function tagesschau_eil:abonnieren(id)
  if redis:sismember(hash..':subs', id) == false then
    redis:sadd(hash..':subs', id)
	return '*Eilmeldungen abonniert.*'
  else
    return 'Die Eilmeldungen wurden hier bereits abonniert.'
  end
end

function tagesschau_eil:deabonnieren(id)
  if redis:sismember(hash..':subs', id) == true then
    redis:srem(hash..':subs', id)
	return '*Eilmeldungen deabonniert.*'
  else
    return 'Die Eilmeldungen wurden hier noch nicht abonniert.'
  end
end

function tagesschau_eil:action(msg, config)
  local input = utilities.input(msg.text)
  
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(msg.chat.id, tagesschau_eil.doc, true, msg.message_id, true)
	  return
	end
  end

  local id = "user#id" .. msg.from.id
  if msg.chat.type == 'channel' then
    print('Kanäle werden momentan nicht unterstützt')
  end
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    id = 'chat#id'..msg.chat.id
  end

  if input:match('(sub)$') then
	local output = tagesschau_eil:abonnieren(id)
	utilities.send_reply(msg, output, true)
  elseif input:match('(del)$') then
	local output = tagesschau_eil:deabonnieren(id)
	utilities.send_reply(msg, output, true)
  elseif input:match('(sync)$') then
	if not is_sudo(msg, config) then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	tagesschau_eil:cron()
  end
  
  return
end

function tagesschau_eil:cron()
  -- print('EIL: Prüfe...')
  local last_eil = redis:get(hash..':last_entry')
  local res,code  = http.request(url)
  if code ~= 200 then return end
  local data = json.decode(res)
  if not data then return end
  if data == "error" then return end
  if data.error then return end
  if data.breakingnews[1] then
    if data.breakingnews[1].date ~= last_eil then
      local title = '#EIL: <b>'..data.breakingnews[1].headline..'</b>'
      local news = data.breakingnews[1].shorttext or ''
      local posted_at = makeOurDate(data.breakingnews[1].date)..' Uhr'
      post_url = 'http://tagesschau.de'
      if data.breakingnews[1].details ~= "" then
	    post_url = string.gsub(data.breakingnews[1].details, '/api/', '/')
	    post_url = string.gsub(post_url, '.json', '.html')
      end
      local eil = title..'\n<i>'..posted_at..'</i>\n'..news
      redis:set(hash..':last_entry', data.breakingnews[1].date)
	  for _,user in pairs(redis:smembers(hash..':subs')) do
	    local user = string.gsub(user, 'chat%#id', '')
		local user = string.gsub(user, 'user%#id', '')
	    utilities.send_message(user, eil, true, nil, 'HTML', '{"inline_keyboard":[[{"text":"Eilmeldung aufrufen","url":"'..post_url..'"}]]}')
      end
    end
  end
end

return tagesschau_eil
