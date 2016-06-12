local rss = {}

local http = require('socket.http')
local https = require('ssl.https')
local url = require('socket.url')
local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()
local feedparser = require("feedparser")

rss.command = 'rss <sub/del>'

function rss:init(config)
	rss.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('rss', true).table
	rss.doc = [[*
]]..config.cmd_pat..[[rss*: Feed-Abonnements anzeigen
*]]..config.cmd_pat..[[rss* _sub_ _<URL>_: Diesen Feed abonnieren
*]]..config.cmd_pat..[[rss* _del_ _<#>_: Diesen Feed deabonnieren
*]]..config.cmd_pat..[[rss* _sync_: Feeds syncen (nur Superuser)]]
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

function print_subs(id, chat_name)
   local uhash = get_base_redis(id)
   local subs = redis:smembers(uhash)
   local text = '"'..chat_name..'" hat abonniert:\n---------\n'
   for k,v in pairs(subs) do
      text = text .. k .. ") " .. v .. '\n'
   end
   return text
end

function rss:subscribe(id, url)
   local baseurl, protocol = prot_url(url)

   local prothash = get_base_redis(baseurl, "protocol")
   local lasthash = get_base_redis(baseurl, "last_entry")
   local lhash = get_base_redis(baseurl, "subs")
   local uhash = get_base_redis(id)

   if redis:sismember(uhash, baseurl) then
      return "Du hast `"..url.."` bereits abonniert."
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

   return "_"..name.."_ abonniert!"
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

   return "Du hast `"..sub.."` deabonniert."
end

function rss:print_subs(id, chat_name)
   local uhash = get_base_redis(id)
   local subs = redis:smembers(uhash)
   if not subs[1] then
     return 'Keine Feeds abonniert!'
   end
   local text = '*'..chat_name..'* hat abonniert:\n---------\n'
   for k,v in pairs(subs) do
      text = text .. k .. ") " .. v .. '\n'
   end
   return text
end

function rss:action(msg, config)
  local input = utilities.input(msg.text)
  local id = "user#id" .. msg.from.id
  if msg.chat.type == 'channel' then
    print('Kanäle werden momentan nicht unterstützt')
  end
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    id = 'chat#id'..msg.chat.id
  end
  
  if not input then
	if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
      chat_name = msg.chat.title
	else
	  chat_name = msg.chat.first_name
	end
    local output = rss:print_subs(id, chat_name)
	utilities.send_reply(self, msg, output, true)
	return
  end

  if input:match('(sub) (https?://[%w-_%.%?%.:/%+=&%~]+)$') then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	local rss_url = input:match('(https?://[%w-_%.%?%.:/%+=&%~]+)$')
	local output = rss:subscribe(id, rss_url)
	utilities.send_reply(self, msg, output, true)
  elseif input:match('(del) (%d+)$') then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	local rss_url = input:match('(%d+)$')
	local output = rss:unsubscribe(id, rss_url)
	utilities.send_reply(self, msg, output, true)
  elseif input:match('(sync)$') then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	rss:cron(self)
  end
  
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
		   if string.len(v2.content) > 250 then
		     content = string.sub(unescape_for_rss(v2.content:gsub("%b<>", "")), 1, 250) .. '...'
		   else
		     content = unescape_for_rss(v2.content:gsub("%b<>", ""))
		  end
		 elseif v2.summary then
		   if string.len(v2.summary) > 250 then
		     content = string.sub(unescape_for_rss(v2.summary:gsub("%b<>", "")), 1, 250) .. '...'
		   else
		     content = unescape_for_rss(v2.summary:gsub("%b<>", ""))
		   end
		 else
		   content = ''
		 end
		 text = text..'\n*'..title..'*\n'..content..' [Weiterlesen]('..link..')\n'
      end
      if text ~= '' then
         local newlast = newentr[1].id
         redis:set(get_base_redis(base, "last_entry"), newlast)
         for k2, receiver in pairs(redis:smembers(v)) do
		   local receiver = string.gsub(receiver, 'chat%#id', '')
		   local receiver = string.gsub(receiver, 'user%#id', '')
		   utilities.send_message(self, receiver, text, true, nil, true)
         end
      end
   end
end

return rss
