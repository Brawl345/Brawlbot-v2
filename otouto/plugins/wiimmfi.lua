local wiimmfi = {}

local http = require('socket.http')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

function wiimmfi:init(config)
    wiimmfi.triggers = {
      "^/(mkw)$",
      "^/wiimmfi$",
      "^/wfc$"
	}
	wiimmfi.doc = [[*
]]..config.cmd_pat..[[wfc*: Zeigt alle Wiimmfi-Spieler an
*]]..config.cmd_pat..[[mkw*: Zeigt alle Mario-Kart-Wii-Spieler an]]
end

wiimmfi.command = 'wfc, /mkw'

function wiimmfi:getplayer(game)
  local url = 'http://wiimmfi.de/game'
  local res,code = http.request(url)
  if code ~= 200 then return "Fehler beim Abrufen von wiimmfi.de" end
  if game == 'mkw' then
    local players = string.match(res, "<td align%=center><a href%=\"/game/mariokartwii\".->(.-)</a>")
    if players == nil then players = 0 end
    text = 'Es spielen gerade '..players..' Spieler Mario Kart Wii'
  else
    local players = string.match(res, "</tr><tr.->(.-)<th colspan%=3")
    local players = string.gsub(players, "</a></td><td>.-<a href=\".-\">", ": ")
    local players = string.gsub(players, "<td.->", "")
    local players = string.gsub(players, "Wii</td>", "")
    local players = string.gsub(players, "WiiWare</td>", "")
    local players = string.gsub(players, "NDS</td>", "")
    local players = string.gsub(players, "<th.->", "")
    local players = string.gsub(players, "<tr.->", "")
    local players = string.gsub(players, "</tr>", "")
    local players = string.gsub(players, "</th>", "")
    local players = string.gsub(players, "<a.->", "")
    local players = string.gsub(players, "</a>", "")
    local players = string.gsub(players, "</td>", "")
    if players == nil then players = 'Momentan spielt keiner auf Wiimmfi :(' end
    text = players
  end
  return text
end

function wiimmfi:action(msg, config, matches)
  if matches[1] == "mkw" then
    utilities.send_reply(self, msg, wiimmfi:getplayer('mkw'))
    return
  else
    utilities.send_reply(self, msg, wiimmfi:getplayer())
    return
  end
end

return wiimmfi