local fun = {}

local utilities = require('otouto.utilities')

function fun:init(config)
	fun.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('random', true).table
	fun.doc = [[*
]]..config.cmd_pat..[[random* _<Username>_: Schau, was passiert!]]
end

fun.command = 'random <Username>'

function fun:choose_random(user_name, other_user)
  randoms = {
      user_name..' schlägt '..other_user..' mit einem stinkenden Fisch.',
      user_name..' versucht, '..other_user..' mit einem Messer zu töten, bringt sich dabei aber selbst um.',
	  user_name..' versucht, '..other_user..' mit einem Messer zu töten, stolpert aber und schlitzt sich dabei das Knie auf.',
      user_name..' ersticht '..other_user..'.',
	  user_name..' tritt '..other_user..'.',
	  user_name..' hat '..other_user..' umgebracht! Möge er in der Hölle schmoren!',
	  user_name..' hat die Schnauze voll von '..other_user..' und sperrt ihn in einen Schrank.',
	  user_name..' erwürgt '..other_user..'. BILD sprach als erstes mit der Hand.',
	  user_name..' schickt '..other_user..' nach /dev/null.',
	  user_name..' umarmt '..other_user..'.',
	  user_name..' verschenkt eine Kartoffel an '..other_user..'.',
	  user_name..' melkt '..other_user..'. *muuh* :D',
	  user_name..' wirft einen Gameboy auf '..other_user..'.',
	  user_name..' hetzt die NSA auf '..other_user..'.',
	  user_name..' ersetzt alle CDs von '..other_user..' durch Nickelback-CDs.',
  }
  math.randomseed(os.time())
  math.randomseed(os.time())
  local random = math.random(15)
  return randoms[random]
end

function fun:action(msg, config, matches)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(self, msg.chat.id, fun.doc, true, msg.message_id, true)
	  return
	end
  end

  local user_name = get_name(msg)
  local result = fun:choose_random(user_name, input)
  utilities.send_message(self, msg.chat.id, result)
end

return fun
