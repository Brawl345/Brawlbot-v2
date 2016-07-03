local facebook = {}

local http = require('socket.http')
local https = require('ssl.https')
local URL = require('socket.url')
local json = require('dkjson')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')
local redis = (loadfile "./otouto/redis.lua")()

function facebook:init(config)
	if not cred_data.fb_access_token then
		print('Missing config value: fb_access_token.')
		print('facebook.lua will not be enabled.')
		return
	end

    facebook.triggers = {
	  "facebook.com/([A-Za-z0-9-._-]+)/(posts)/(%d+)",
	  "facebook.com/(permalink).php%?(story_fbid)=(%d+)&id=(%d+)",
      "facebook.com/(photo).php%?fbid=(%d+)",
      "facebook.com/([A-Za-z0-9-._-]+)/(photos)/a.(%d+[%d%.]*)/(%d+)",
      "facebook.com/(video).php%?v=(%d+)",
	  "facebook.com/([A-Za-z0-9-._-]+)/(videos)/(%d+[%d%.]*)",
	  "facebook.com/([A-Za-z0-9-._-]+)"
	}
end

local BASE_URL = 'https://graph.facebook.com/v2.5'
local fb_access_token = cred_data.fb_access_token

local makeOurDate = function(dateString)
  local pattern = "(%d+)%/(%d+)%/(%d+)"
  local month, day, year = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function facebook:get_fb_id(name)
  local url = BASE_URL..'/'..name..'?access_token='..fb_access_token..'&locale=de_DE'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  return data.id
end

function facebook:fb_post (id, story_id)
  local url = BASE_URL..'/'..id..'_'..story_id..'?access_token='..fb_access_token..'&locale=de_DE&fields=from,name,story,message,link'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  
  local from = data.from.name
  local message = data.message
  local name = data.name
  if data.link then
    link = '\n'..data.name..':\n'..utilities.md_escape(data.link)
  else
    link = ""
  end
  
  if data.story then
    story = ' ('..data.story..')'
  else
    story = ""
  end
  
  local text = '*'..from..'*'..story..':\n'..message..'\n'..link
  return text
end

function facebook:send_facebook_photo(photo_id, receiver)
  local url = BASE_URL..'/'..photo_id..'?access_token='..fb_access_token..'&locale=de_DE&fields=images,from,name'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  
  local from = '*'..data.from.name..'*'
  if data.name then
    text = from..' hat ein Bild gepostet:\n'..data.name
  else
    text = from..' hat ein Bild gepostet:'
  end
  local image_url = data.images[1].source
  return text, image_url
end

function facebook:send_facebook_video(video_id)
  local url = BASE_URL..'/'..video_id..'?access_token='..fb_access_token..'&locale=de_DE&fields=description,from,source,title'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)

  local from = '*'..data.from.name..'*'
  local description = data.description
  local source = data.source
  return from..' hat ein Video gepostet:\n'..description, source, data.title
end

function facebook:facebook_info(name)
  local url = BASE_URL..'/'..name..'?access_token='..fb_access_token..'&locale=de_DE&fields=about,name,birthday,category,founded,general_info,is_verified'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  
  local name = data.name
  if data.is_verified then
    name = name..' ✅'
  end
  
  local category = data.category
  
  if data.about then
    about = '\n'..data.about
  else
    about = ""
  end
  
  if data.general_info then
    general_info = '\n'..data.general_info
  else
    general_info = ""
  end
  
  if data.birthday and data.founded then
    birth = '\nGeburtstag: '..makeOurDate(data.birthday)
  elseif data.birthday and not data.founded then
    birth = '\nGeburtstag: '..makeOurDate(data.birthday)
  elseif data.founded and not data.birthday then
    birth = '\nGegründet: '..data.founded
  else
    birth = ""
  end
  
  local text = '*'..name..'* ('..category..')_'..about..'_'..general_info..birth
  return text
end

function facebook:action(msg, config, matches)
  if matches[1] == 'permalink' or matches[2] == 'posts' then
    story_id = matches[3]
    if not matches[4] then
	  id = facebook:get_fb_id(matches[1])
	else
	  id = matches[4]
	end
	utilities.send_reply(self, msg, facebook:fb_post(id, story_id), true)
    return
  elseif matches[1] == 'photo' or matches[2] == 'photos' then
    if not matches[4] then
      photo_id = matches[2]
    else
      photo_id = matches[4]
    end
    local text, image_url = facebook:send_facebook_photo(photo_id, receiver)
	if not image_url then return end
	utilities.send_typing(self, msg.chat.id, 'upload_photo')
	local file = download_to_file(image_url, 'photo.jpg')
	utilities.send_reply(self, msg, text, true)
	utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
	return
  elseif matches[1] == 'video' or matches[2] == 'videos' then
    if not matches[3] then
      video_id = matches[2]
    else
      video_id = matches[3]
    end
    local output, video_url, title = facebook:send_facebook_video(video_id)
	if not title then
	  title = 'Video aufrufen'
	else
	  title = 'VIDEO: '..title
	end
	if not video_url then return end
	utilities.send_reply(self, msg, output, true, '{"inline_keyboard":[[{"text":"'..utilities.md_escape(title)..'","url":"'..video_url..'"}]]}')
	return
  else
    utilities.send_reply(self, msg, facebook:facebook_info(matches[1]), true)
    return
  end
end

return facebook