local settings = {}

settings.triggers = {
  "^(⚙ [Ee]instellungen)$",
  "^(/settings)$",
  "^(💤 [Aa][Ff][Kk]%-[Kk]eyboard einschalten)",
  "^(💤 [Aa][Ff][Kk]%-[Kk]eyboard ausschalten)",
  "^(❌ [Ee]instellungen verstecken)"
}

--[[

[
  [ "Top Left", "Top Right" ],
  [ "Bottom Left", "Bottom Right" ]
]

]]

function settings:keyboard(user_id)
  if redis:hget('user:'..user_id, 'afk_keyboard') == 'true' then
    afk_button = '{"text":"💤 AFK-Keyboard ausschalten"}'
  else
    afk_button = '{"text":"💤 AFK-Keyboard einschalten"}'
  end
  local hide_settings_button = '{"text":"❌ Einstellungen verstecken"}'
  
  local settings_keyboard = '[['..afk_button..','..hide_settings_button..']]'
  return settings_keyboard
end

function settings:action(msg, config, matches)
  if msg.chat.type ~= "private" then
    return
  end
  
  local hash = 'user:'..msg.from.id

  if matches[1] == '⚙ Einstellungen' or matches[1] == '/settings' then
    utilities.send_reply(self, msg, 'Was möchtest du einstellen?', false, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '💤 AFK-Keyboard einschalten' then
    redis:hset(hash, 'afk_keyboard', 'true')
	utilities.send_reply(self, msg, 'Das AFK-Keyboard wurde erfolgreich *eingeschaltet*.', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '💤 AFK-Keyboard ausschalten' then
    redis:hset(hash, 'afk_keyboard', 'false')
	utilities.send_reply(self, msg, 'Das AFK-Keyboard wurde erfolgreich *ausgeschaltet*.', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '❌ Einstellungen verstecken' then
	utilities.send_reply(self, msg, 'Um die Einstellungen wieder einzublenden, führe /settings aus.', true, '{"hide_keyboard":true}')
	return
  end
end

return settings