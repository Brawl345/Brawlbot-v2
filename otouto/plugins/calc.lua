local calc = {}

local URL = require('socket.url')
local http = require('socket.http')
local utilities = require('otouto.utilities')

calc.command = 'calc <Ausdruck>'

function calc:init(config)
	calc.triggers = {
	"^/calc (.*)$"
	}
	calc.doc = [[*
]]..config.cmd_pat..[[calc* _[Ausdruck]_: Rechnet]]
end

function calc:mathjs(exp)
  local exp = string.gsub(exp, ",", "%.")
  local url = 'http://api.mathjs.org/v1/'
  url = url..'?expr='..URL.escape(exp)
  local b,c = http.request(url)
  local text = nil
  if c == 200 then
    text = '= '..string.gsub(b, "%.", ",")
  
  elseif c == 400 then
    text = b
  else
    text = 'Unerwarteter Fehler\n'
      ..'Ist api.mathjs.org erreichbar?'
  end
  return text
end

function calc:action(msg, config, matches)
  utilities.send_reply(self, msg, calc:mathjs(matches[1]))
end

return calc
