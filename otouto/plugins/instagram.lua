local instagram = {}

function instagram:init(config)
  if not cred_data.instagram_access_token then
	print('Missing config value: instagram_access_token.')
	print('instagram.lua will not be enabled.')
	return
  end

  instagram.triggers = {
	"instagram.com/p/([A-Za-z0-9-_-]+)"
  }
end

local BASE_URL = 'https://api.instagram.com/v1'
local access_token = cred_data.instagram_access_token

function instagram:get_insta_data(insta_code)
  local url = BASE_URL..'/media/shortcode/'..insta_code..'?access_token='..access_token
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res).data
  return data
end

function instagram:send_instagram_data(data)
  -- Header
  local username = data.user.username
  local full_name = data.user.full_name
  if username == full_name then
    header = full_name..' hat ein'
  else
    header = full_name..' ('..username..') hat ein'
  end
  if data.type == 'video' then
    header = header..' Video gepostet'
  else
    header = header..' Foto gepostet'
  end
  
  -- Caption
  if data.caption == nil then
    caption = ''
  else
    caption = ':\n'..data.caption.text
  end
  
  -- Footer
  local comments = comma_value(data.comments.count)
  local likes = comma_value(data.likes.count)
  local footer = '\n'..likes..' Likes, '..comments..' Kommentare'
  if data.type == 'video' then
    footer = '\n'..data.videos.standard_resolution.url..footer
  end
  
  -- Image
  local image_url = data.images.standard_resolution.url
  
  return header..caption..footer, image_url
end

function instagram:action(msg, config, matches)
  local insta_code = matches[1]
  local data = instagram:get_insta_data(insta_code)
  if not data then utilities.send_reply(msg, config.errors.connection) return end
  
  local text, image_url = instagram:send_instagram_data(data)
  if not image_url then utilities.send_reply(msg, config.errors.connection) return end
  
  utilities.send_typing(msg.chat.id, 'upload_photo')
  local file = download_to_file(image_url)
  utilities.send_photo(msg.chat.id, file, text, msg.message_id)
end

return instagram
