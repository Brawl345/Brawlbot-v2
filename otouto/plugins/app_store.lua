local app_store = {}

app_store.triggers = {
	"itunes.apple.com/(.*)/app/(.*)/id(%d+)",
	"^/itunes (%d+)$",
	"itunes.apple.com/app/id(%d+)"
}
	
local BASE_URL = 'https://itunes.apple.com/lookup'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function app_store:get_appstore_data()
  local url = BASE_URL..'/?id='..appid..'&country=de'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).results[1]
  
  if data == nil then return 'NOTFOUND' end
  if data.wrapperType ~= 'software' then return nil end
  
  return data
end

function app_store:send_appstore_data(data)  
  -- Header
  local name = data.trackName
  local author = data.sellerName
  local price = data.formattedPrice
  local version = data.version
  
  -- Body
  local description = string.sub(unescape(data.description), 1, 150) .. '...'
  local min_ios_ver = data.minimumOsVersion
  local size = string.gsub(round(data.fileSizeBytes / 1000000, 2), "%.", ",") -- wtf Apple, it's 1024, not 1000!
  local release = makeOurDate(data.releaseDate)
  if data.isGameCenterEnabled then
    game_center = '\nUnterstützt Game Center'
  else
    game_center = ''
  end
  local category_count = tablelength(data.genres)
  if category_count == 1 then
    category = '\nKategorie: '..data.genres[1]
  else
    local category_loop = '\nKategorien: '
    for v in pairs(data.genres) do
      if v < category_count then
        category_loop = category_loop..data.genres[v]..', '
	  else
	    category_loop = category_loop..data.genres[v]
	  end
    end
	  category = category_loop
  end
  
  -- Footer
  if data.averageUserRating and data.userRatingCount then
    avg_rating = 'Bewertung: '..string.gsub(data.averageUserRating, "%.", ",")..' Sterne '
	ratings = 'von '..comma_value(data.userRatingCount)..' Bewertungen'
  else
    avg_rating = ""
	ratings = ""
  end
  
  
  local header = '<b>'..name..'</b> v'..version..' von <b>'..author..'</b> ('..price..'):'
  local body = '\n'..description..'\n<i>Benötigt mind. iOS '..min_ios_ver..'</i>\nGröße: '..size..' MB\nErstveröffentlicht am '..release..game_center..category
  local footer = '\n'..avg_rating..ratings
  local text = header..body..footer
  
  -- Picture
  if data.screenshotUrls[1] and data.ipadScreenshotUrls[1] then
    image_url = data.screenshotUrls[1]
  elseif data.screenshotUrls[1] and not data.ipadScreenshotUrls[1] then
    image_url = data.screenshotUrls[1]
  elseif not data.screenshotUrls[1] and data.ipadScreenshotUrls[1] then
    image_url = data.ipadScreenshotUrls[1]
  else
    image_url = nil
  end
  
  return text, image_url
end

function app_store:action(msg, config, matches)
  if not matches[3] then
    appid = matches[1]
  else
    appid = matches[3]
  end
  local data = app_store:get_appstore_data()
  if data == nil then print('Das Appstore-Plugin unterstützt nur Apps!') end
  if data == 'HTTP-FEHLER' or data == 'NOTFOUND' then
    utilities.send_reply(msg, '<b>App nicht gefunden!</b>', 'HTML')
    return
  else
    local output, image_url = app_store:send_appstore_data(data)
    utilities.send_reply(msg, output, 'HTML')
	if image_url then
	  utilities.send_typing(msg.chat.id, 'upload_photo')
	  local file = download_to_file(image_url)
	  utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
	end
  end
end

return app_store
