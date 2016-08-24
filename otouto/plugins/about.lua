local about = {}

local bot = require('otouto.bot')

about.command = 'about'
about.doc = '`Sendet Informationen über den Bot.`'

function about:init(config)
  about.text = config.about_text..'\n[Brawlbot](https://github.com/Brawl345/Brawlbot-v2) v'..bot.version..', basierend auf [Otouto](http://github.com/topkecleon/otouto) von topkecleon.'
  about.triggers = {
	'/about',
	'/start'
  }
end

function about:action(msg, config)
  utilities.send_message(msg.chat.id, about.text, true, nil, true)
end

return about
