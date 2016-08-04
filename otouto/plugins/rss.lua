local rss = {}

local feedparser = require("feedparser")

rss.command = 'rss <sub/del>'

function rss:init(config)
	rss.triggers = {
	  "^/(rss) @(.*)$",
      "^/rss$",
      "^/rss (sub) (https?://[%w-_%.%?%.:/%+=&%~]+) @(.*)$",
      "^/rss (sub) (https?://[%w-_%.%?%.:/%+=&%~]+)$",
      "^/rss (del) (%d+) @(.*)$",
      "^/rss (del) (%d+)$",
	  "^/rss (del)",
      "^/rss (sync)$"	
	}
	rss.doc = [[*
]]..config.cmd_pat..[[rss* _@[Kanalname]_: Feed-Abonnements anzeigen
*]]..config.cmd_pat..[[rss* _sub_ _<URL>_ _@[Kanalname]_: Diesen Feed abonnieren
*]]..config.cmd_pat..[[rss* _del_ _<#>_ _@[Kanalname]_: Diesen Feed deabonnieren
*]]..config.cmd_pat..[[rss* _sync_: Feeds syncen (nur Superuser)
Der Kanalname ist optional]]
end

function tail(n, k)
  local u, r=''
  for i=1,k do
    n,r = math.floor(n/0x40), n%0x40
    u = string.char(r+0x80) .. u
  end
  return u, n
end
 
function to_utf8(a)
  local n, r, u = tonumber(a)
  if n<0x80 then                        -- 1 byte
    return string.char(n)
  elseif n<0x800 then                   -- 2 byte
    u, n = tail(n, 1)
    return string.char(n+0xc0) .. u
  elseif n<0x10000 then                 -- 3 byte
    u, n = tail(n, 2)
    return string.char(n+0xe0) .. u
  elseif n<0x200000 then                -- 4 byte
    u, n = tail(n, 3)
    return string.char(n+0xf0) .. u
  elseif n<0x4000000 then               -- 5 byte
    u, n = tail(n, 4)
    return string.char(n+0xf8) .. u
  else                                  -- 6 byte
    u, n = tail(n, 5)
    return string.char(n+0xfc) .. u
  end
end

function unescape_for_rss(str)
  str = string.gsub( str, '&lt;', '<' )
  str = string.gsub( str, '&gt;', '>' )
  str = string.gsub( str, '&quot;', '"' )
  str = string.gsub( str, '&apos;', "'" )
  str = string.gsub( str, "&Auml;", "Ä")
  str = string.gsub( str, "&auml;", "ä")
  str = string.gsub( str, "&Ouml;", "Ö")
  str = string.gsub( str, "&ouml;", "ö")
  str = string.gsub( str, "Uuml;", "Ü")
  str = string.gsub( str, "&uuml;", "ü")
  str = string.gsub( str, "&szlig;", "ß")
  str = string.gsub(str, '&#(%d+);', to_utf8)
  str = string.gsub( str, '&#x(%d+);', function(n) return string.char(tonumber(n,16)) end )
  str = string.gsub( str, '&amp;', '&' ) -- Be sure to do this after all others
  return str
end

function get_base_redis(id, option, extra)
   local ex = ''
   if option ~= nil then
      ex = ex .. ':' .. option
      if extra ~= nil then
         ex = ex .. ':' .. extra
      end
   end
   return 'rss:' .. id .. ex
end

function prot_url(url)
   local url, h = string.gsub(url, "http://", "")
   local url, hs = string.gsub(url, "https://", "")
   local protocol = "http"
   if hs == 1 then
      protocol = "https"
   end
   return url, protocol
end

function get_rss(url, prot)
   local res, code = nil, 0
   if prot == "http" then
      res, code = http.request(url)
   elseif prot == "https" then
      res, code = https.request(url)
   end
   if code ~= 200 then
      return nil, "Fehler beim Erreichen von " .. url
   end
   local parsed = feedparser.parse(res)
   if parsed == nil then
      return nil, "Fehler beim Dekodieren des Feeds.\nBist du sicher, dass "..url.." ein Feed ist?"
   end
   return parsed, nil
end

function get_new_entries(last, nentries)
   local entries = {}
   for k,v in pairs(nentries) do
      if v.id == last then
         return entries
      else
         table.insert(entries, v)
      end
   end
   return entries
end

function rss:subscribe(id, url)
   local baseurl, protocol = prot_url(url)

   local prothash = get_base_redis(baseurl, "protocol")
   local lasthash = get_base_redis(baseurl, "last_entry")
   local lhash = get_base_redis(baseurl, "subs")
   local uhash = get_base_redis(id)

   if redis:sismember(uhash, baseurl) then
      return "Du hast <code>"..url.."</code> bereits abonniert."
   end

   local parsed, err = get_rss(url, protocol)
   if err ~= nil then
      return err
   end

   local last_entry = ""
   if #parsed.entries > 0 then
      last_entry = parsed.entries[1].id
   end

   local name = parsed.feed.title

   redis:set(prothash, protocol)
   redis:set(lasthash, last_entry)
   redis:sadd(lhash, id)
   redis:sadd(uhash, baseurl)

   return "<i>"..name.."</i> abonniert!"
end

function rss:unsubscribe(id, n)
   if #n > 5 then
      return "Du kannst nicht mehr als fünf Feeds abonnieren!"
   end
   n = tonumber(n)

   local uhash = get_base_redis(id)
   local subs = redis:smembers(uhash)
   if n < 1 or n > #subs then
      return "Abonnement-ID zu hoch!"
   end
   local sub = subs[n]
   local lhash = get_base_redis(sub, "subs")

   redis:srem(uhash, sub)
   redis:srem(lhash, id)

   local left = redis:smembers(lhash)
   if #left < 1 then -- no one subscribed, remove it
      local prothash = get_base_redis(sub, "protocol")
      local lasthash = get_base_redis(sub, "last_entry")
      redis:del(prothash)
      redis:del(lasthash)
   end

   return "Du hast <code>"..sub.."</code> deabonniert."
end

function rss:print_subs(id, chat_name)
   local uhash = get_base_redis(id)
   local subs = redis:smembers(uhash)
   if not subs[1] then
     return '<b>Keine Feeds abonniert!</b>'
   end
   local keyboard = '{"keyboard":[['
   local keyboard_buttons = ''
   local text = '<b>'..chat_name..'</b> hat abonniert:\n---------\n'
   for k,v in pairs(subs) do
      text = text .. k .. ") " .. v .. '\n'
	  if k == #subs then
	    keyboard_buttons = keyboard_buttons..'{"text":"/rss del '..k..'"}'
		break;
	  end
	  keyboard_buttons = keyboard_buttons..'{"text":"/rss del '..k..'"},'
   end
   local keyboard = keyboard..keyboard_buttons..']], "one_time_keyboard":true, "selective":true, "resize_keyboard":true}'
   return text, keyboard
end

function rss:action(msg, config, matches)
  local id = "user#id" .. msg.from.id
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    id = 'chat#id'..msg.chat.id
  end
  
  -- For channels
  if matches[1] == 'sub' and matches[2] and matches[3] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	local id = '@'..matches[3]
	local result = utilities.get_chat_info(self, id)
	if not result then
	  utilities.send_reply(self, msg, 'Diesen Kanal gibt es nicht!')
	  return
	end
	local output = rss:subscribe(id, matches[2])
	utilities.send_reply(self, msg, output, 'HTML')
	return
  elseif matches[1] == 'del' and matches[2] and matches[3] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	local id = '@'..matches[3]
	local result = utilities.get_chat_info(self, id)
	if not result then
	  utilities.send_reply(self, msg, 'Diesen Kanal gibt es nicht!')
	  return
	end
	local output = rss:unsubscribe(id, matches[2])
	utilities.send_reply(self, msg, output, 'HTML')
	return
  elseif matches[1] == 'rss' and matches[2] then
    local id = '@'..matches[2]
	local result = utilities.get_chat_info(self, id)
	if not result then
	  utilities.send_reply(self, msg, 'Diesen Kanal gibt es nicht!')
	  return
	end
	local chat_name = result.result.title
    local output = rss:print_subs(id, chat_name)
	utilities.send_reply(self, msg, output, 'HTML')
	return
  end
  
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
	chat_name = msg.chat.title
  else
	chat_name = msg.chat.first_name
  end
  
  if matches[1] == 'sub' and matches[2] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	local output = rss:subscribe(id, matches[2])
	utilities.send_reply(self, msg, output, 'HTML')
	return
  elseif matches[1] == 'del' and matches[2] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	local output = rss:unsubscribe(id, matches[2])
	utilities.send_reply(self, msg, output, 'HTML', '{"hide_keyboard":true}')
	return
  elseif matches[1] == 'del' and not matches[2] then
    local list_subs, keyboard = rss:print_subs(id, chat_name)
	utilities.send_reply(self, msg, list_subs, 'HTML', keyboard)
    return
  elseif matches[1] == 'sync' then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	rss:cron(self)
	return
  end
  
  local output = rss:print_subs(id, chat_name)
  utilities.send_reply(self, msg, output, 'HTML')
  return
end

function rss:cron(self_plz)
   if not self.BASE_URL then
     self = self_plz
   end
   local keys = redis:keys(get_base_redis("*", "subs"))
   for k,v in pairs(keys) do
      local base = string.match(v, "rss:(.+):subs")  -- Get the URL base
	  print('RSS: '..base)
      local prot = redis:get(get_base_redis(base, "protocol"))
      local last = redis:get(get_base_redis(base, "last_entry"))
      local url = prot .. "://" .. base
      local parsed, err = get_rss(url, prot)
      if err ~= nil then
         return
      end
	  -- local feed_title = parsed.feed.title
      local newentr = get_new_entries(last, parsed.entries)
      local subscribers = {}
      local text = ''  -- Send one message per feed with the latest entries
      for k2, v2 in pairs(newentr) do
         local title = v2.title or 'Kein Titel'
         local link = v2.link or v2.id or 'Kein Link'
		 if v2.content then
		   content = v2.content:gsub("%b<>", "")
		   if string.len(v2.content) > 250 then
			 content = unescape_for_rss(content)
		     content = string.sub(content, 1, 250)..'...'
		   else
		     content = unescape_for_rss(content)
		  end
		 elseif v2.summary then
		   content = v2.summary:gsub("%b<>", "")
		   if string.len(v2.summary) > 250 then
		     content = unescape_for_rss(content)
		     content = string.sub(content, 1, 250)..'...'
		   else
		     content = unescape_for_rss(content)
		   end
		 else
		   content = ''
		 end
		 text = text..'\n#RSS: <b>'..title..'</b>\n'..utilities.trim(content)..' <a href="'..link..'">Weiterlesen</a>\n'
      end
      if text ~= '' then
         local newlast = newentr[1].id
         redis:set(get_base_redis(base, "last_entry"), newlast)
         for k2, receiver in pairs(redis:smembers(v)) do
		   local receiver = string.gsub(receiver, 'chat%#id', '')
		   local receiver = string.gsub(receiver, 'user%#id', '')
		   utilities.send_message(self, receiver, text, true, nil, 'HTML')
         end
      end
   end
end

return rss