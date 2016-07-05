local images = {}

local utilities = require('otouto.utilities')
images.triggers = {
  "(https?://[%w-_%%%.%?%.:,/%+=~&%[%]]+%.[Pp][Nn][Gg])$",
  "(https?://[%w-_%%%.%?%.:,/%+=~&%[%]]+%.[Jj][Pp][Ee]?[Gg])$"
}

function images:action(msg)
  local url = matches[1]
  local file, last_modified, nocache = get_cached_file(url, nil, msg.chat.id, 'upload_photo', self)
  local result = utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)

  if nocache then return end
  if not result then return end

  -- Cache File-ID und Last-Modified-Header in Redis
  cache_file(result, url, last_modified)
end

return images
