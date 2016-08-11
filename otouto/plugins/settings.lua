--  SWITCH YOUR EDITOR TO UTF-8 (Notepad++ sets this file to ANSI)
local settings = {}

settings.triggers = {
  "^(⚙ [Ee]instellungen)$",
  "^(/settings)$",
  "^(↩️ [Zz]urück)$",
  "^(💤 [Aa][Ff][Kk]%-[Kk]eyboard einschalten)$",
  "^(💤 [Aa][Ff][Kk]%-[Kk]eyboard ausschalten)$",
  "^(❌ [Ee]instellungen verstecken)$",
  "^(▶️ [Vv]ideoauflösung für [Yy]ou[Tt]ube%-[Dd][Ll] einstellen)$",
  "^(▶️ 144p)$",
  "^(▶️ 180p)$",
  "^(▶️ 360p [Ww]eb[Mm])$",
  "^(▶️ 360p [Mm][Pp]4)$",
  "^(▶️ 720p)$"
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
  local youtube_dl_res_button = '{"text":"▶️ Videoauflösung für YouTube-DL einstellen"}'
  local hide_settings_button = '{"text":"❌ Einstellungen verstecken"}'
  
  local settings_keyboard = '[['..afk_button..','..youtube_dl_res_button..'],['..hide_settings_button..']]'
  return settings_keyboard
end

function settings:youtube_dl_keyboard()
  local worst = '{"text":"▶️ 144p"}'
  local still_worse = '{"text":"▶️ 180p"}'
  local better_webm = '{"text":"▶️ 360p WebM"}'
  local better_mp4 = '{"text":"▶️ 360p MP4"}'
  local best = '{"text":"▶️ 720p"}'
  local back = '{"text":"↩️ Zurück"}'
  
  local youtube_dl_keyboard = '[['..best..','..better_mp4..','..better_webm..'],['..still_worse..','..worst..'],['..back..']]'
  return youtube_dl_keyboard
end

function settings:action(msg, config, matches)
  if msg.chat.type ~= "private" then
    return
  end
  
  local hash = 'user:'..msg.from.id

  -- General
  if matches[1] == '⚙ Einstellungen' or matches[1] == '/settings' or matches[1] == '↩️ Zurück' then
    utilities.send_reply(self, msg, 'Was möchtest du einstellen?', false, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '❌ Einstellungen verstecken' then
	utilities.send_reply(self, msg, 'Um die Einstellungen wieder einzublenden, führe /settings aus.', true, '{"hide_keyboard":true}')
	return
  end
  
  -- AFK keyboard
  if matches[1] == '💤 AFK-Keyboard einschalten' then
    redis:hset(hash, 'afk_keyboard', 'true')
	utilities.send_reply(self, msg, 'Das AFK-Keyboard wurde erfolgreich *eingeschaltet*.', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '💤 AFK-Keyboard ausschalten' then
    redis:hset(hash, 'afk_keyboard', 'false')
	utilities.send_reply(self, msg, 'Das AFK-Keyboard wurde erfolgreich *ausgeschaltet*.', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  end
  
  -- YouTube-DL video resolution
  -- 144p: 17
  -- 180p: 36
  -- 360p WebM: 43
  -- 360p MP4: 18
  -- 720p: 22
  if matches[1] == '▶️ Videoauflösung für YouTube-DL einstellen' then
    utilities.send_reply(self, msg, 'Welche Videoauflösung bevorzugst du?\n<b>HINWEIS:</b> Dies gilt nur für <code>/mp4</code>. Wenn die gewählte Auflösung nicht zur Verfügung steht, wird die nächsthöhere bzw. bei 720p die nächstniedrigere genommen.', 'HTML', '{"keyboard":'..settings:youtube_dl_keyboard()..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
  elseif matches[1] == '▶️ 144p' then
    local resolution_order = '17/36/43/18/22'
    redis:hset(hash, 'yt_dl_res_ordner', resolution_order)
	utilities.send_reply(self, msg, 'Die Reihenfolge ist jetzt folgende:\n1) 144p\n2) 180p\n3) 360p WebM\n4) 360p MP4\n5) 720p', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '▶️ 180p' then
    local resolution_order = '36/17/43/18/22'
    redis:hset(hash, 'yt_dl_res_ordner', resolution_order)
	utilities.send_reply(self, msg, 'Die Reihenfolge ist jetzt folgende:\n1) 180p\n2) 144p\n3) 360p WebM\n4) 360p MP4\n5) 720p', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '▶️ 360p WebM' then
    local resolution_order = '43/18/36/17/22'
    redis:hset(hash, 'yt_dl_res_ordner', resolution_order)
	utilities.send_reply(self, msg, 'Die Reihenfolge ist jetzt folgende:\n1) 360p WebM\n2) 360p MP4\n3) 180p\n4) 144p\n5) 720p', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '▶️ 360p MP4' then
    local resolution_order = '18/43/36/17/22'
    redis:hset(hash, 'yt_dl_res_ordner', resolution_order)
	utilities.send_reply(self, msg, 'Die Reihenfolge ist jetzt folgende:\n1) 360p MP4\n2) 360p WebM\n3) 180p\n4) 144p\n5) 720p', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  elseif matches[1] == '▶️ 720p' then
    local resolution_order = '22/18/43/36/17'
    redis:hset(hash, 'yt_dl_res_ordner', resolution_order)
	utilities.send_reply(self, msg, 'Die Reihenfolge ist jetzt folgende:\n1) 720p\n2) 360p MP4\n3) 360p WebM\n4) 180p\n5) 144p', true, '{"keyboard":'..settings:keyboard(msg.from.id)..', "one_time_keyboard":true, "selective":true, "resize_keyboard":true}')
	return
  end

end

return settings