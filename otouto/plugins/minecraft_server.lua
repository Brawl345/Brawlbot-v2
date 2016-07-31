local mc_server = {}

function mc_server:init(config)
	mc_server.triggers = {
	"^/mine (.*)$"
	}
	mc_server.doc = [[*
]]..config.cmd_pat..[[mine* _<IP>_: Sucht Minecraft-Server und sendet Infos. Standard-Port: 25565
*]]..config.cmd_pat..[[mine* _<IP>_ _<Port>_: Sucht Minecraft-Server auf Port und sendet Infos.
]]
end

mc_server.command = "mine <IP> [Port]"

function mc_server:mineSearch(ip, port)
  local responseText = ""
  local api = "https://mcapi.us/server/status"
  local parameters = "?ip="..(URL.escape(ip) or "").."&port="..(URL.escape(port) or "").."&players=true"
  local respbody = {} 
  local body, code, headers, status = http.request{
    url = api..parameters,
    method = "GET",
    redirect = true,
    sink = ltn12.sink.table(respbody)
  }
  local body = table.concat(respbody)
  if (status == nil) then return "FEHLER: status = nil" end
  if code ~=200 then return "FEHLER: "..code..". Status: "..status end
  local jsonData = json.decode(body)
  responseText = responseText..ip..":"..port..":\n"
  if (jsonData.motd ~= nil and jsonData.motd ~= '') then
    local tempMotd = ""
    tempMotd = jsonData.motd:gsub('%ยง.', '')
    if (jsonData.motd ~= nil) then responseText = responseText.."*MOTD*: "..tempMotd.."\n" end
  end
  if (jsonData.online ~= nil) then
    if jsonData.online == true then
	  server_online = "Ja"
	else
	  server_online = "Nein"
	end
    responseText = responseText.."*Online*: "..server_online.."\n"
  end
  if (jsonData.players ~= nil) then
    if (jsonData.players.max ~= nil and jsonData.players.max ~= 0) then
      responseText = responseText.."*Slots*: "..jsonData.players.max.."\n"
    end
    if (jsonData.players.now ~= nil and jsonData.players.max ~= 0) then
      responseText = responseText.."*Spieler online*: "..jsonData.players.now.."\n"
    end
    if (jsonData.players.sample ~= nil and jsonData.players.sample ~= false) then
      responseText = responseText.."*Spieler*: "..table.concat(jsonData.players.sample, ", ").."\n"
    end
	if (jsonData.server.name ~= nil and jsonData.server.name ~= "") then
      responseText = responseText.."*Server*: "..jsonData.server.name.."\n"
    end
  end
  return responseText
end

function mc_server:parseText(text, mc_server)
  if (text == nil or text == "/mine") then
    return mc_server.doc
  end
  ip, port = string.match(text, "^/mine (.-) (.*)$")
  if (ip ~= nil and port ~= nil) then
    return mc_server:mineSearch(ip, port)
  end
  local ip = string.match(text, "^/mine (.*)$")
  if (ip ~= nil) then
    return mc_server:mineSearch(ip, "25565")
  end
  return "FEHLER: Keine Input IP!"
end

function mc_server:action(msg, config, matches)
  utilities.send_reply(self, msg, mc_server:parseText(msg.text, mc_server), true)
end

return mc_server
