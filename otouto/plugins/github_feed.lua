local gh_feed = {}

gh_feed.command = 'gh <sub/del>'

function gh_feed:init(config)
	if not cred_data.github_token then
		print('Missing config value: github_token.')
		print('github_feed.lua will not be enabled.')
		return
	elseif not cred_data.github_username then
		print('Missing config value: github_username.')
		print('github_feed.lua will not be enabled.')
		return
	end

	gh_feed.triggers = {
	  "^/(gh) @(.*)$",
      "^/gh$",
      "^/gh (sub) ([A-Za-z0-9-_-.-._.]+/[A-Za-z0-9-_-.-._.]+) @(.*)$",
      "^/gh (sub) ([A-Za-z0-9-_-.-._.]+/[A-Za-z0-9-_-.-._.]+)$",
      "^/gh (del) (%d+) @(.*)$",
      "^/gh (del) (%d+)$",
	  "^/gh (del)",
      "^/gh (sync)$"	
	}
	gh_feed.doc = [[*
]]..config.cmd_pat..[[gh* _@[Kanalname]_: GitHub-Abonnements anzeigen
*]]..config.cmd_pat..[[gh* _sub_ _<URL>_ _@[Kanalname]_: Diese Repo abonnieren
*]]..config.cmd_pat..[[gh* _del_ _<#>_ _@[Kanalname]_: Diese Repo deabonnieren
*]]..config.cmd_pat..[[gh* _sync_: Repos syncen (nur Superuser)
Der Kanalname ist optional]]
end

local token = cred_data.github_token -- get a token here: https://github.com/settings/tokens/new (you don't need any scopes)
local BASE_URL = 'https://api.github.com/repos'

function gh_feed_get_base_redis(id, option, extra)
   local ex = ''
   if option ~= nil then
      ex = ex .. ':' .. option
      if extra ~= nil then
         ex = ex .. ':' .. extra
      end
   end
   return 'github:' .. id .. ex
end

function gh_feed_check_modified(repo, cur_etag, last_date)
  local url = BASE_URL..'/'..repo
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "HEAD",
	  redirect = false,
      headers = {
	    Authorization = 'token '..token,
		["If-None-Match"] = cur_etag
	  }
   }
  local ok, response_code = https.request(request_constructor)
  if not ok then return nil end
  if response_code == 304 then return true end

  local url = BASE_URL..'/'..repo..'/commits?since='..last_date
  local response_body = {}
  local request_constructor = {
	url = url,
	method = "GET",
	sink = ltn12.sink.table(response_body),
	headers = {
	  Authorization = 'token '..token
	}
  }
  local ok, response_code, response_headers = https.request(request_constructor)
  if not response_headers then return nil end
  local data = json.decode(table.concat(response_body))
  return false, data, response_headers.etag
end

function gh_feed:check_repo(repo)
  local url = BASE_URL..'/'..repo
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body),
      headers = {
	    Authorization = 'token '..token
	  }
   }
  local ok, response_code, response_headers = https.request(request_constructor)
  if not ok then return nil end
  return json.decode(table.concat(response_body)), response_headers.etag
end

function gh_feed:subscribe(id, repo)
  local lasthash = gh_feed_get_base_redis(repo, "last_commit")
  local lastetag = gh_feed_get_base_redis(repo, "etag")
  local lastdate = gh_feed_get_base_redis(repo, "date")
  local lhash = gh_feed_get_base_redis(repo, "subs")
  local uhash = gh_feed_get_base_redis(id)
   
  if redis:sismember(uhash, repo) then
    return "Du hast `"..repo.."` bereits abonniert."
  end
  
  local data, etag = gh_feed:check_repo(repo)
  if not data or not data.full_name then return 'Diese Repo gibt es nicht!' end
  if not etag then return 'Ein Fehler ist aufgetreten.' end
  
  local last_commit = ""
  local pushed_at = data.pushed_at
  local name = data.full_name
  
  redis:set(lasthash, last_commit)
  redis:set(lastdate, pushed_at)
  redis:set(lastetag, etag)
  redis:sadd(lhash, id)
  redis:sadd(uhash, repo)
   
  return "_"..utilities.md_escape(name) .."_ abonniert!"
end

function gh_feed:unsubscribe(id, n)
   if #n > 3 then
      return "Du kannst nicht mehr als drei Repos abonnieren!"
   end
   n = tonumber(n)

   local uhash = gh_feed_get_base_redis(id)
   local subs = redis:smembers(uhash)
   if n < 1 or n > #subs then
      return "Abonnement-ID zu hoch!"
   end
   local sub = subs[n]
   local lhash = gh_feed_get_base_redis(sub, "subs")

   redis:srem(uhash, sub)
   redis:srem(lhash, id)

   local left = redis:smembers(lhash)
   if #left < 1 then -- no one subscribed, remove it
      local lastetag = gh_feed_get_base_redis(sub, "etag")
	  local lastdate = gh_feed_get_base_redis(sub, "date")
      local lasthash = gh_feed_get_base_redis(sub, "last_commit")
      redis:del(lastetag)
      redis:del(lasthash)
	  redis:del(lastdate)
   end

   return "Du hast `"..utilities.md_escape(sub).."` deabonniert."
end

function gh_feed:print_subs(id, chat_name)
   local uhash = gh_feed_get_base_redis(id)
   local subs = redis:smembers(uhash)
   if not subs[1] then
     return 'Keine GitHub-Repos abonniert!'
   end
   local keyboard = '{"keyboard":[['
   local keyboard_buttons = ''
   local text = '*'..chat_name..'* hat abonniert:\n---------\n'
   for k,v in pairs(subs) do
      text = text .. k .. ") ["..v.."](https://github.com/"..v..')\n'
	  if k == #subs then
	    keyboard_buttons = keyboard_buttons..'{"text":"/gh del '..k..'"}'
		break;
	  end
	  keyboard_buttons = keyboard_buttons..'{"text":"/gh del '..k..'"},'
   end
   local keyboard = keyboard..keyboard_buttons..']], "one_time_keyboard":true, "selective":true, "resize_keyboard":true}'
   return text, keyboard
end

function gh_feed:action(msg, config, matches)
  local id = msg.from.id
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    id = msg.chat.id
  end
  
  -- For channels
  if matches[1] == 'sub' and matches[2] and matches[3] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	local id = '@'..matches[3]
	local result = utilities.get_chat_info(id)
	if not result then
	  utilities.send_reply(msg, 'Diesen Kanal gibt es nicht!')
	  return
	end
	local output = gh_feed:subscribe(id, matches[2])
	utilities.send_reply(msg, output, true)
	return
  elseif matches[1] == 'del' and matches[2] and matches[3] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	local id = '@'..matches[3]
	local result = utilities.get_chat_info(id)
	if not result then
	  utilities.send_reply(msg, 'Diesen Kanal gibt es nicht!')
	  return
	end
	local output = gh_feed:unsubscribe(id, matches[2])
	utilities.send_reply(msg, output, true)
	return
  elseif matches[1] == 'gh' and matches[2] then
    local id = '@'..matches[2]
	local result = utilities.get_chat_info(id)
	if not result then
	  utilities.send_reply(msg, 'Diesen Kanal gibt es nicht!')
	  return
	end
	local chat_name = result.result.title
    local output = gh_feed:print_subs(id, chat_name)
	utilities.send_reply(msg, output, true)
	return
  end
  
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
	chat_name = msg.chat.title
  else
	chat_name = msg.chat.first_name
  end

  if matches[1] == 'sub' and matches[2] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	local output = gh_feed:subscribe(id, matches[2])
	utilities.send_reply(msg, output, true)
	return
  elseif matches[1] == 'del' and matches[2] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	local output = gh_feed:unsubscribe(id, matches[2])
	utilities.send_reply(msg, output, true, '{"hide_keyboard":true}')
	return
  elseif matches[1] == 'del' and not matches[2] then
    local list_subs, keyboard = gh_feed:print_subs(id, chat_name)
	utilities.send_reply(msg, list_subs, true, keyboard)
    return
  elseif matches[1] == 'sync' then
    if msg.from.id ~= config.admin then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	gh_feed:cron()
	return
  end
  
  local output = gh_feed:print_subs(id, chat_name)
  utilities.send_reply(msg, output, true)
  return
end

function gh_feed:cron()
   local keys = redis:keys(gh_feed_get_base_redis("*", "subs"))
   for k,v in pairs(keys) do
     local repo = string.match(v, "github:(.+):subs")
	 print('GitHub: '..repo)
	 local cur_etag = redis:get(gh_feed_get_base_redis(repo, "etag"))
	 local last_date = redis:get(gh_feed_get_base_redis(repo, "date"))
	 local was_not_modified, data, last_etag = gh_feed_check_modified(repo, cur_etag, last_date)
	 if not was_not_modified then
	   if not data or not last_etag then return end
	   -- When there are new commits
	   local last_commit = redis:get(gh_feed_get_base_redis(repo, "last_commit")) 
	   text = ''
	   for n in ipairs(data) do
	     if data[n].sha ~= last_commit then
		   local sha = data[n].sha
		   local author = data[n].commit.author.name
		   local message = utilities.md_escape(data[n].commit.message)
		   local link = data[n].html_url
		   text = text..'\n#GitHub: `'..repo..'@'..sha..'` von *'..author..'*:\n'..message..'\n[GitHub aufrufen]('..link..')\n'
	     end
	   end
	   if text ~= '' then
	     local last_commit = data[1].sha
	     local last_date = data[1].commit.author.date
	     redis:set(gh_feed_get_base_redis(repo, "last_commit"), last_commit)
	     redis:set(gh_feed_get_base_redis(repo, "etag"), last_etag)
	     redis:set(gh_feed_get_base_redis(repo, "date"), last_date)
	     for k2, receiver in pairs(redis:smembers(v)) do
	       utilities.send_message(receiver, text, true, nil, true)
	     end
	   end
    end
  end
end

return gh_feed