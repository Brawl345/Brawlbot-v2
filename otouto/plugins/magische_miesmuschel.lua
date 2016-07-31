local muschel = {}

muschel.triggers = {
	"^[Mm][Aa][Gg][Ii][Ss][Cc][Hh][Ee] [Mm][Ii][Ee][Ss][Mm][Uu][Ss][Cc][Hh][Ee][Ll], (.*)$"
}

function muschel:frag_die_muschel()
  local possibilities = {
	"Ja",
	"Nein",
	"Eines Tages vielleicht"
  }
  local random = math.random(3)
  return possibilities[random]
end

function muschel:action(msg, config, matches)
  utilities.send_reply(self, msg, muschel:frag_die_muschel())
end

return muschel
