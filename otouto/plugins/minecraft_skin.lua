local mc_skin = {}

function mc_skin:init(config)
  mc_skin.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('skin', true).table
  mc_skin.doc = [[*
]]..config.cmd_pat..[[skin* _<Username>_: Sendet Minecraft-Skin dieses Nutzers]]
end

mc_skin.command = 'skin <Username>'

local BASE_URL = 'http://ip-api.com/json'

function mc_skin:action(msg, config, matches)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(self, msg.chat.id, mc_skin.doc, true, msg.message_id, true)
	  return
	end
  end

  local url = 'http://www.minecraft-skin-viewer.net/3d.php?layers=true&aa=true&a=0&w=330&wt=10&abg=330&abd=40&ajg=340&ajd=20&ratio=13&format=png&login='..input..'&headOnly=false&displayHairs=true&randomness=341.png'
  local file = download_to_file(url)
  utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
end

return mc_skin
