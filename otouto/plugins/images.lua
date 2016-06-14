local images = {}

local utilities = require('otouto.utilities')
images.triggers = {
  "(https?://[%w-_%%%.%?%.:,/%+=~&%[%]]+%.[Pp][Nn][Gg])$",
  "(https?://[%w-_%%%.%?%.:,/%+=~&%[%]]+%.[Jj][Pp][Ee]?[Gg])$"
}

function images:action(msg)
   utilities.send_typing(self, msg.chat.id, 'upload_photo')
   local url = matches[1]
   local file = download_to_file(url)
   utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
end

return images
