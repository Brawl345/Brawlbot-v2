local cln_amzn = {}

cln_amzn.triggers = {
  'amazon.(%w+)/gp/product/(.+)/(.+)',
  'amazon.(%w+)/gp/product/(.+)%?(.+)',
  'amazon.(%w+)/dp/(.+)/(.+)',
  'amazon.(%w+)/dp/(.+)%?(.+)',
  'amzn.to/(.+)'
}

function cln_amzn:action(msg, config, matches)
  if #matches == 1 then
   local request_constructor = {
      url = 'http://amzn.to/'..matches[1],
      method = "HEAD",
      sink = ltn12.sink.null(),
      redirect = false
   }

   local ok, response_code, response_headers = http.request(request_constructor)
   local long_url = response_headers.location
   if not long_url then return end
   local domain, product_id = long_url:match('amazon.(%w+)/gp/product/(.+)/.+')
   if not product_id then
     domain, product_id = long_url:match('amazon.(%w+)/.+/dp/(.+)/')
   end
   if not product_id then return end
   utilities.send_reply(msg, 'Ohne Ref: https://amazon.'..domain..'/dp/'..product_id)
   return
  end

  text = msg.text:lower()
  if text:match('tag%=.+') or text:match('linkid%=.+') then
    utilities.send_reply(msg, 'Ohne Ref: https://amazon.'..matches[1]..'/dp/'..matches[2])
  end
end

return cln_amzn