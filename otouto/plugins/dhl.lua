local dhl = {}

function dhl:init(config)
	dhl.triggers = {
	"/dhl (%d+)$"
	}
	dhl.doc = [[*
]]..config.cmd_pat..[[dhl* _<Sendungsnummer>_: Aktueller Status der Sendung]]
end


local BASE_URL = 'https://mobil.dhl.de'

function dhl:sendungsstatus(id)
  local url = BASE_URL..'/shipmentdetails.html?shipmentId='..id
  local res,code = https.request(url)
  if code ~= 200 then return "Fehler beim Abrufen von mobil.dhl.de" end
  local status = string.match(res, "<div id%=\"detailShortStatus\">(.-)</div>")
  local status = all_trim(status)
  local zeit = string.match(res, "<div id%=\"detailStatusDateTime\">(.-)</div>")
  local zeit = all_trim(zeit)
  if not zeit or zeit == '<br />' then
    return status
  end
  return '*'..status..'*\n_Stand: '..zeit..'_'
end

function dhl:action(msg, config, matches)
  local sendungs_id = matches[1]
  if string.len(sendungs_id) < 8 then return end
  utilities.send_reply(msg, dhl:sendungsstatus(sendungs_id), true)
end

return dhl
