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
	other_user..' melkt '..user_name..'. *muuh* :D',
	user_name..' ist in '..other_user..' verliebt.',
	user_name..' schmeißt '..other_user..' in einen Fluss.',
	user_name..' klaut '..other_user..' einen Lolli.',
	user_name..' hätte gern Sex mit '..other_user..'.',
	user_name..' schenkt '..other_user..' ein Foto von seinem Penis.',
	user_name..' dreht durch und wirft '..other_user..' in einen Häcksler.',
	user_name..' gibt '..other_user..' einen Keks.',
	user_name..' lacht '..other_user..' aus.',
	user_name..' gibt '..other_user..[[ ganz viel Liebe. ( ͡° ͜ʖ ͡°)]],
	user_name..' lädt '..other_user..' zum Essen ein.',
	user_name..' schwatzt '..other_user..' Ubuntu auf.',
	user_name..' fliegt mit '..other_user..' nach Hawaii.',
	user_name..' küsst '..other_user..' leidenschaftlich.'
  }
  math.randomseed(os.time())
  math.randomseed(os.time())
  local random = math.random(#randoms)
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
