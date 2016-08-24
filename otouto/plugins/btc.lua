local btc = {}

function btc:init(config)
	btc.triggers = {
	  "^/btc$"
	}
	btc.doc = [[*
]]..config.cmd_pat..[[btc*: Zeigt aktuellen Bitcoin-Kurs an]]
end

btc.command = 'btc'
  
-- See https://bitcoinaverage.com/api
function btc:getBTCX()
  local base_url = 'https://api.bitcoinaverage.com/ticker/global/'
  -- Do request on bitcoinaverage, the final / is critical!
  local res,code  = https.request(base_url.."EUR/")
  
  if code ~= 200 then return nil end
  local data = json.decode(res)
  local ask = string.gsub(data.ask, "%.", ",")
  local bid = string.gsub(data.bid, "%.", ",")

  -- Easy, it's right there
  text = 'BTC/EUR\n'..'*Kaufen:* '..ask..'\n'..'*Verkaufen:* '..bid
  return text
end


function btc:action(msg, config, matches)
  utilities.send_reply(msg, btc:getBTCX(cur), true)
end

return btc