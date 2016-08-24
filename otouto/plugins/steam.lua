local steam = {}

steam.triggers = {
  "store.steampowered.com/app/([0-9]+)",
  "steamcommunity.com/app/([0-9]+)"
}

local BASE_URL = 'http://store.steampowered.com/api/appdetails/'
local DESC_LENTH = 400

function steam:get_steam_data(appid)
  local url = BASE_URL
  url = url..'?appids='..appid
  url = url..'&l=german&cc=DE'
  local res,code  = http.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)[appid].data
  return data
end

function steam:price_info(data)
  local price = '' -- If no data is empty
  
  if data then
    local initial = data.initial
    local final = data.final or data.initial
    local min = math.min(data.initial, data.final)
    price = tostring(min/100)
    if data.discount_percent and initial ~= final then
      price = price..data.currency..' ('..data.discount_percent..'% OFF)'
    end
    price = price..' €'
  end

  return price
end

function steam:send_steam_data(data, msg)
  local description = string.sub(unescape(data.about_the_game:gsub("%b<>", "")), 1, DESC_LENTH) .. '...'
  local title = data.name
  local price = steam:price_info(data.price_overview)

  local text = '*'..title..'* _'..price..'_\n'..description
  local image_url = data.header_image
  return text, image_url
end

function steam:action(msg)
  local data = steam:get_steam_data(matches[1])
  if not data then utilities.send_reply(msg, config.errors.connection) return end

  local text, image_url = steam:send_steam_data(data, msg)
  utilities.send_typing(msg.chat.id, 'upload_photo')
  utilities.send_photo(msg.chat.id, download_to_file(image_url, matches[1]..'.jpg'), nil, msg.message_id)
  utilities.send_reply(msg, text, true)
end

return steam