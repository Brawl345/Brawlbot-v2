local currency = {}

currency.command = 'cash [Menge] <von> <zu>'

function currency:init(config)
	currency.triggers = {
      "^/cash ([A-Za-z]+)$",
      "^/cash ([A-Za-z]+) ([A-Za-z]+)$",
	  "^/cash (%d+[%d%.,]*) ([A-Za-z]+) ([A-Za-z]+)$",
	  "^(/cash)$"
	}
	currency.inline_triggers = {
	  "^c ([A-Za-z]+)$",
	  "^c ([A-Za-z]+) ([A-Za-z]+)$",
	  "^c (%d+[%d%.,]*) ([A-Za-z]+) ([A-Za-z]+)$"
	}
	currency.doc = [[*
]]..config.cmd_pat..[[cash* _[Menge]_ _<von>_ _<zu>_
*]]..config.cmd_pat..[[cash* _<von>_: Rechnet in Euro um
*]]..config.cmd_pat..[[cash* _<von>_ _<zu>_: Rechnet mit der Einheit 1
Beispiel: _]]..config.cmd_pat..[[cash 5 USD EUR_]]
end

local BASE_URL = 'https://api.fixer.io'

function currency:inline_callback(inline_query, config, matches)
  if not matches[2] then -- first pattern
    base = 'EUR'
	to = string.upper(matches[1])
	amount = 1
  elseif matches[3] then -- third pattern
    base  = string.upper(matches[2])
	to = string.upper(matches[3])
	amount = matches[1]
  else -- second pattern
    base = string.upper(matches[1])
	to = string.upper(matches[2])
	amount = 1
  end
  
  local value, iserr = currency:convert_money(base, to, amount)
  if iserr then utilities.answer_inline_query(self, inline_query) return end
  
  local output = amount..' '..base..' = *'..value..' '..to..'*'
  if tonumber(amount) == 1 then
    title = amount..' '..base..' entspricht'
  else
    title = amount..' '..base..' entsprechen'
  end
  local results = '[{"type":"article","id":"20","title":"'..title..'","description":"'..value..' '..to..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/currency/cash.jpg","thumb_width":157,"thumb_height":140,"input_message_content":{"message_text":"'..output..'","parse_mode":"Markdown"}}]'
  utilities.answer_inline_query(self, inline_query, results, 3600)
end

function currency:convert_money(base, to, amount)
  local url = BASE_URL..'/latest?base='..base..'&symbols='..to
  local amount = string.gsub(amount, ",", ".")
  local amount = tonumber(amount)
  local res, code = https.request(url)
  if code ~= 200 and code ~= 422 then
    return 'NOCONNECT', true
  end
  
  local res, code = https.request(url)
  local data = json.decode(res)
  if data.error then
    return 'WRONGBASE', true
  end
  
  local rate = data.rates[to]
  if not rate then
	 return 'WRONGCONVERTRATE', true
  end
  
  if amount == 1 then
    value = round(rate, 2)
  else
    value = round(rate * amount, 2)
  end
  local value = tostring(string.gsub(value, "%.", ","))

  return value
end

function currency:action(msg, config, matches)
  if matches[1] == '/cash' then
    utilities.send_reply(self, msg, currency.doc, true)
    return
  elseif not matches[2] then -- first pattern
    base = 'EUR'
	to = string.upper(matches[1])
	amount = 1
  elseif matches[3] then -- third pattern
    base  = string.upper(matches[2])
	to = string.upper(matches[3])
	amount = matches[1]
  else -- second pattern
    base = string.upper(matches[1])
	to = string.upper(matches[2])
	amount = 1
  end

  if from == to then
    utilities.send_reply(self, msg, 'Jaja, sehr witzig...')
	return
  end

  local value = currency:convert_money(base, to, amount)
  if value == 'NOCONNECT' then
    utilities.send_reply(self, msg, config.errors.connection)
    return
  elseif value == 'WRONGBASE' then 
    utilities.send_reply(self, msg, 'Keine gültige Basiswährung.')
	return
  elseif value == 'WRONGCONVERTRATE' then
    utilities.send_reply(self, msg, 'Keine gültige Umwandlungswährung.')
	return
  end

  local output = amount..' '..base..' = *'..value..' '..to..'*'
  utilities.send_reply(self, msg, output, true)
end

return currency