local youtube = {}

local utilities = require('otouto.utilities')
local https = require('ssl.https')
local JSON = require('dkjson')
local bindings = require('otouto.bindings')

function youtube:init(config)
	if not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('youtube.lua will not be enabled.')
		return
	end
	
	youtube.triggers = {
		'youtu.be/([A-Za-z0-9-_-]+)',
		'youtube.com/embed/([A-Za-z0-9-_-]+)',
		'youtube.com/watch%?v=([A-Za-z0-9-_-]+)'
	}
	youtube.doc = [[*YouTube-Link*: Postet Infos zu Video]]
end

local apikey = cred_data.google_apikey

local BASE_URL = 'https://www.googleapis.com/youtube/v3'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function get_yt_data (yt_code)
  local apikey = cred_data.google_apikey
  local url = BASE_URL..'/videos?part=snippet,statistics,contentDetails&key='..apikey..'&id='..yt_code..'&fields=items(snippet(publishedAt,channelTitle,localized(title,description),thumbnails),statistics(viewCount,likeCount,dislikeCount,commentCount),contentDetails(duration,regionRestriction(blocked)))'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = JSON.decode(res).items[1]
  return data
end

local function convertISO8601Time(duration)
	local a = {}

	for part in string.gmatch(duration, "%d+") do
	   table.insert(a, part)
	end

	if duration:find('M') and not (duration:find('H') or duration:find('S')) then
		a = {0, a[1], 0}
	end

	if duration:find('H') and not duration:find('M') then
		a = {a[1], 0, a[2]}
	end

	if duration:find('H') and not (duration:find('M') or duration:find('S')) then
		a = {a[1], 0, 0}
	end

	duration = 0

	if #a == 3 then
		duration = duration + tonumber(a[1]) * 3600
		duration = duration + tonumber(a[2]) * 60
		duration = duration + tonumber(a[3])
	end

	if #a == 2 then
		duration = duration + tonumber(a[1]) * 60
		duration = duration + tonumber(a[2])
	end

	if #a == 1 then
		duration = duration + tonumber(a[1])
	end

	return duration
end

function send_youtube_data(data, msg, self, link, sendpic)
  local title = data.snippet.localized.title
  local title = title:gsub('%*', '\\*')
  local title = title:gsub('`', '\\`')
  -- local description = data.snippet.localized.description
  local uploader = data.snippet.channelTitle
  local upload_date = makeOurDate(data.snippet.publishedAt)
  local viewCount = comma_value(data.statistics.viewCount)
  if data.statistics.likeCount then
    likeCount = ', '..comma_value(data.statistics.likeCount)..' Likes und '
	dislikeCount = comma_value(data.statistics.dislikeCount)..' Dislikes'
  else
    likeCount = ''
	dislikeCount = ''
  end

  if data.statistics.commentCount then
    commentCount = ', '..comma_value(data.statistics.commentCount)..' Kommentare'
  else
    commentCount = ''
  end

  local totalseconds = convertISO8601Time(data.contentDetails.duration)
  local duration = makeHumanTime(totalseconds)
  if data.contentDetails.regionRestriction then
    blocked = data.contentDetails.regionRestriction.blocked
    blocked = table.contains(blocked, "DE")
  else
    blocked = false
  end
  
  text = '*'..title..'*\n_('..uploader..' am '..upload_date..', '..viewCount..'x angesehen, Länge: '..duration..likeCount..dislikeCount..commentCount..')_\n'
  if link then
    text = link..'\n'..text
  end
  
  if blocked then
    text = text..'\n*ACHTUNG, Video ist in Deutschland gesperrt!*'
  end
  
  if sendpic then
    if data.snippet.thumbnails.maxres then
      image_url = data.snippet.thumbnails.maxres.url
	elseif data.snippet.thumbnails.high then
	  image_url = data.snippet.thumbnails.high.url
	elseif data.snippet.thumbnails.medium then
	  image_url = data.snippet.thumbnails.medium.url
	elseif data.snippet.thumbnails.standard then
	  image_url = data.snippet.thumbnails.standard.url
	else
	  image_url = data.snippet.thumbnails.default.url
	end
	-- need to change text, because Telegram captions can only be 200 characters long and don't support Markdown
	local text = link..'\n'..title..'\n('..uploader..' am '..upload_date..', '..viewCount..'x angesehen, Länge: '..duration..')'
	if blocked then
      text = text..'\nACHTUNG, In Deutschland gesperrt!'
    end
    local file = download_to_file(image_url)
	utilities.send_photo(self, msg.chat.id, file, text, msg.message_id)
  else
    utilities.send_reply(self, msg, text, true)
  end
end

function youtube:action(msg, config, matches)
  local yt_code = matches[1]
  local data = get_yt_data(yt_code)
  send_youtube_data(data, msg, self)
  return
end

return youtube