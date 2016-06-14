local gSearch = {}

local HTTPS = require('ssl.https')
local URL = require('socket.url')
local JSON = require('dkjson')
local utilities = require('otouto.utilities')

gSearch.command = 'google <query>'

function gSearch:init(config)
	gSearch.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('g', true):t('google', true):t('gnsfw', true).table
	gSearch.doc = [[```
]]..config.cmd_pat..[[google <Suchbegriff>
Sendet Suchergebnisse von Google
Alias: ]]..config.cmd_pat..[[g
```]]
end

function gSearch:googlethat(query, config)
  local BASE_URL = 'https://www.googleapis.com/customsearch/v1'
  local apikey = cred_data.google_apikey
  local cseid = cred_data.google_cse_id
  local number = 5 -- Set number of results 

  local api        = BASE_URL.."/?key="..apikey.."&cx="..cseid.."&gl=de&num="..number.."&safe=medium&fields=searchInformation%28formattedSearchTime,formattedTotalResults%29,items%28title,link,displayLink%29&"
  local parameters = "q=".. (URL.escape(query) or "")
  -- Do the request
  local res, code = HTTPS.request(api..parameters)
  if code == 403 then
    utilities.send_reply(self, msg, config.errors.quotaexceeded)
	return
  end
  if code ~= 200 then
    utilities.send_reply(self, msg, config.errors.connection)
	return
  end
  local data = JSON.decode(res)
  if data.searchInformation.formattedTotalResults == "0" then return nil end
  
  local results={}
  for key,result in ipairs(data.items) do
    table.insert(results, {
	  result.title,
      result.link,
	  result.displayLink
    })
  end
  
  local stats = data.searchInformation.formattedTotalResults..' Ergebnisse, gefunden in '..data.searchInformation.formattedSearchTime..' Sekunden'
  return results, stats
end

function gSearch:stringlinks(results, stats)
  local stringresults=""
  for key,val in ipairs(results) do
    stringresults=stringresults.."["..val[1].."]("..val[2]..") - `"..val[3].."`\n"
  end
  return stringresults..stats
end

function gSearch:action(msg, config)
  local input = utilities.input(msg.text)
  if not input then
	if msg.reply_to_message and msg.reply_to_message.text then
	  input = msg.reply_to_message.text
	else
	  utilities.send_message(self, msg.chat.id, gSearch.doc, true, msg.message_id, true)
	  return
	end
  end
  
  local results, stats = gSearch:googlethat(input, config)
  utilities.send_message(self, msg.chat.id, gSearch:stringlinks(results, stats), true, nil, true)

end

return gSearch