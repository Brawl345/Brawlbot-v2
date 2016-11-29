local youtube = {}

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
	youtube.inline_triggers = {
	  "^yt (.+)"
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
  local data = json.decode(res).items[1]
  return data
end

function convertISO8601Time(duration)
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

function get_yt_thumbnail(data)
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
  return image_url
end

function send_youtube_data(data, msg, self, link, sendpic)
  local title = data.snippet.localized.title
  -- local description = data.snippet.localized.description
  local uploader = data.snippet.channelTitle
  local upload_date = makeOurDate(data.snippet.publishedAt)
  local viewCount = comma_value(data.statistics.viewCount)
  if data.statistics.likeCount then
    likeCount = ' | 👍 <i>'..comma_value(data.statistics.likeCount)..'</i> |'
	dislikeCount = ' 👎 <i>'..comma_value(data.statistics.dislikeCount)..'</i>'
  else
    likeCount = ''
	dislikeCount = ''
  end

  if data.statistics.commentCount then
    commentCount = ' | 🗣 <i>'..comma_value(data.statistics.commentCount)..'</i>'
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
  
  text = '<b>'..title..'</b>\n🎥 <b>'..uploader..'</b>, 📅 <i>'..upload_date..'</i>\n👁 <i>'..viewCount..'</i> | 🕒 <i>'..duration..'</i>'..likeCount..dislikeCount..commentCount..'\n'
  if link then
    text = link..'\n'..text
  end
  
  if blocked then
    text = text..'\n<b>ACHTUNG, Video ist in Deutschland gesperrt!</b>'
  end
  
  if sendpic then
    local image_url = get_yt_thumbnail(data)
	-- need to change text, because Telegram captions can only be 200 characters long and don't support Markdown
    local text = link..'\n'..title..'\n🎥 '..uploader..', 📅 '..upload_date..'\n👁 '..viewCount..' | 🕒 '..duration..likeCount..dislikeCount..commentCount..'\n'
	if blocked then
      text = text..'\nACHTUNG, In Deutschland gesperrt!'
    end
	utilities.send_photo(msg.chat.id, image_url, text, msg.message_id)
  else
    utilities.send_reply(msg, text, 'HTML')
  end
end

function youtube:inline_callback(inline_query, config, matches)
  local query = matches[1]
  local url = BASE_URL..'/search?part=snippet&key='..apikey..'&maxResults=10&type=video&q='..URL.escape(query)..'&fields=items(id(videoId),snippet(publishedAt,title,thumbnails,channelTitle))'
  local res,code  = https.request(url)
  if code ~= 200 then abort_inline_query(inline_query) return end

  local data = json.decode(res)
  if not data.items[1] then abort_inline_query(inline_query) return end
  
  local video_ids = ""
  -- We get all videoIds from search...
  for num in pairs(data.items) do
    video_ids = video_ids..data.items[num].id.videoId
	if num < #data.items then
	  video_ids = video_ids..','
	end
  end
  
  -- ...and do a second query to get all video infos
  local url = BASE_URL..'/videos?part=snippet,statistics,contentDetails&key='..apikey..'&id='..video_ids..'&fields=items(id,snippet(publishedAt,channelTitle,localized(title,description),thumbnails),statistics(viewCount,likeCount,dislikeCount,commentCount),contentDetails(duration,regionRestriction(blocked)))'
  local res,code  = https.request(url)
  if code ~= 200 then return end

  local video_results = json.decode(res)
  if not video_results.items[1] then return end

  local results = '['
  local id = 800
  for num in pairs(video_results.items) do
    local video_url = 'https://www.youtube.com/watch?v='..video_results.items[num].id
    local thumb_url = get_yt_thumbnail(video_results.items[num])
	local video_duration = convertISO8601Time(video_results.items[num].contentDetails.duration)
	local video_title = video_results.items[num].snippet.localized.title:gsub('"', '\\"')
  
    if video_results.items[num].statistics.likeCount then
      likeCount = ', '..comma_value(video_results.items[num].statistics.likeCount)..' Likes, '
	  dislikeCount = comma_value(video_results.items[num].statistics.dislikeCount)..' Dislikes'
    else
      likeCount = ''
	  dislikeCount = ''
    end

    if video_results.items[num].statistics.commentCount then
      commentCount = ', '..comma_value(video_results.items[num].statistics.commentCount)..' Kommentare'
    else
      commentCount = ''
    end

	local readable_dur = makeHumanTime(video_duration)
	local viewCount = comma_value(video_results.items[num].statistics.viewCount)
	local uploader = video_results.items[num].snippet.channelTitle
	local description = uploader..', '..viewCount..' Views, '..readable_dur..likeCount..dislikeCount..commentCount
	
    results = results..'{"type":"video","id":"'..id..'","video_url":"'..video_url..'","mime_type":"text/html","thumb_url":"'..thumb_url..'","title":"'..video_title..'","description":"'..description..'","video_duration":'..video_duration..',"input_message_content":{"message_text":"'..video_url..'"}}'
	id = id+1
	if num < #video_results.items then
	 results = results..','
	end
  end
  local results = results..']'
  utilities.answer_inline_query(inline_query, results, 0)
end

function youtube:action(msg, config, matches)
  local yt_code = matches[1]
  local data = get_yt_data(yt_code)
  if not data then
    utilities.send_reply(msg, config.errors.results)
	return
  end
  send_youtube_data(data, msg, self)
  return
end

return youtube