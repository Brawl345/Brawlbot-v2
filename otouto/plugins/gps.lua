local gps = {}

gps.command = 'gps <Breitengrad>,<Längengrad>'

function gps:init(config)
	gps.triggers = {
    "^/gps ([^,]*)[,%s]([^,]*)$",
	"google.de/maps/@([^,]*)[,%s]([^,]*)",
	"google.com/maps/@([^,]*)[,%s]([^,]*)",
	"google.de/maps/place/@([^,]*)[,%s]([^,]*)",
	"google.com/maps/place/@([^,]*)[,%s]([^,]*)"
	}
	gps.doc = [[*
]]..config.cmd_pat..[[gps* _<Breitengrad>_,_<Längengrad>_: Sendet Karte mit diesen Koordinaten]]
end

function gps:action(msg, config, matches)
  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  local lat = matches[1]
  local lon = matches[2]

  local zooms = {16, 18}

  local urls = {}
  for i in ipairs(zooms) do
    local zoom = zooms[i]
    local url = "https://maps.googleapis.com/maps/api/staticmap?zoom=" .. zoom .. "&size=600x300&maptype=hybrid&center=" .. lat .. "," .. lon .. "&markers=color:red%7Clabel:•%7C" .. lat .. "," .. lon
    local file = download_to_file(url, 'zoom_'..i..'.png')
	utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
  end

  utilities.send_location(self, msg.chat.id, lat, lon, msg.message_id)
end

return gps
