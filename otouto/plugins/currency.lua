local currency = {}

local HTTPS = require('ssl.https')
local utilities = require('otouto.utilities')

currency.command = 'cash [Menge] <von> in <zu>'

function currency:init(config)
	currency.triggers = {
      "^/cash ([A-Za-z]+)$",
      "^/cash ([A-Za-z]+) ([A-Za-z]+)$",
	  "^/cash (%d+[%d%.,]*) ([A-Za-z]+) ([A-Za-z]+)$",
  	"^(/eur)$"
	}
	currency.doc = [[*
]]..config.cmd_pat..[[cash* _[Menge]_ _<von>_ _<zu>_
Beispiel: _]]..config.cmd_pat..[[cash 5 USD EUR_]]
end

function currency:action(msg, config)
  if not matches[2] then
    from = string.upper(matches[1])
	to = 'EUR'
	amount = 1
  elseif matches[3] then
    from = string.upper(matches[2])
	to = string.upper(matches[3])
	amount = matches[1]
  else
    from = string.upper(matches[1])
	to = string.upper(matches[2])
	amount = 1
  end
  
  local amount = string.gsub(amount, ",", ".")
  amount = tonumber(amount)
  local result = 1
  local BASE_URL = 'https://www.google.com/finance/converter'
  if from == to then
    utilities.send_reply(self, msg, 'Jaja, sehr witzig...')
	return
  end
  
  local url = BASE_URL..'?from='..from..'&to='..to..'&a='..amount
  local str, res = HTTPS.request(url)
  if res ~= 200 then
    utilities.send_reply(self, msg, config.errors.connection)
    return
  end
  
  local str = str:match('<span class=bld>(.*) %u+</span>')
  if not str then
	utilities.send_reply(self, msg, 'Keine gültige Währung - sieh dir die Währungsliste bei [Google Finanzen](https://www.google.com/finance/converter) an.', true)
	return
  end
  local result = string.format('%.2f', str)
  local result = string.gsub(result, "%.", ",")

  local amount = tostring(string.gsub(amount, "%.", ","))
  local output = amount..' '..from..' = *'..result..' '..to..'*'
  utilities.send_reply(self, msg, output, true)
end

return currency