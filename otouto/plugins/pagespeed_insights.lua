local pagespeed_insights = {}

function pagespeed_insights:init(config)
  if not cred_data.google_apikey then
	print('Missing config value: google_apikey.')
	print('pagespeed_insights.lua will not be enabled.')
	return
  end

  pagespeed_insights.triggers = {
	"^/speed (https?://[%w-_%.%?%.:/%+=&]+)"
  }
	pagespeed_insights.doc = [[*
]]..config.cmd_pat..[[speed* _<Seiten-URL>_: Testet Geschwindigkeit der Seite mit PageSpeed Insights]]
end

local BASE_URL = 'https://www.googleapis.com/pagespeedonline/v2'

function pagespeed_insights:get_pagespeed(test_url)
  local apikey = cred_data.google_apikey
  local url = BASE_URL..'/runPagespeed?url='..test_url..'&key='..apikey..'&fields=id,ruleGroups(SPEED(score))'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res)
  return data.id..' hat einen PageSpeed-Score von *'..data.ruleGroups.SPEED.score..' Punkten.*'
end

function pagespeed_insights:action(msg, config, matches)
  utilities.send_typing(msg.chat.id, 'typing')
  local text = pagespeed_insights:get_pagespeed(matches[1])
  if not text then utilities.send_reply(msg, config.errors.connection) return end
  utilities.send_reply(msg, text, true)
end

return pagespeed_insights
