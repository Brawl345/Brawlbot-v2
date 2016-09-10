local migrate = {}

migrate.triggers = {
  '^//tgservice migrate_to_chat_id$'
}

function migrate:action(msg, config, matches)
  if not is_service_msg(msg) then return end -- Bad attempt at trolling!

  local old_id = msg.chat.id
  local new_id = msg.migrate_to_chat_id
  print('Migrating every data from '..old_id..' to '..new_id..'...')
  print('--- SUPERGROUP MIGRATION STARTED ---')

  local keys = redis:keys('*'..old_id..'*')
  for k,v in pairs(keys) do
    local string_before_id = string.match(v, '(.+)'..old_id..'.+') or string.match(v, '(.+)'..old_id)
	local string_after_id = string.match(v, '.+'..old_id..'(.+)') or ''
	print(string_before_id..old_id..string_after_id..' -> '..string_before_id..new_id..string_after_id)
	redis:rename(string_before_id..old_id..string_after_id, string_before_id..new_id..string_after_id)
  end
  
  -- Migrate GH feed
  local keys = redis:keys('github:*:subs')
  if keys then
    for k,v in pairs(keys) do
      local repo = string.match(v, "github:(.+):subs")
	  local is_in_set = redis:sismember('github:'..repo..':subs', old_id)
	  if is_in_set then
	    print('github:'..repo..':subs - Changing ID in set...')
	    redis:srem('github:'..repo..':subs', old_id)
		redis:sadd('github:'..repo..':subs', new_id)
	  end
    end
  end
  
  -- Migrate RSS feed
  local keys = redis:keys('rss:*:subs')
  if keys then
    for k,v in pairs(keys) do
      local feed = string.match(v, "rss:(.+):subs")
	  local is_in_set = redis:sismember('rss:'..feed..':subs', 'chat#id'..old_id)
	  if is_in_set then
	    print('rss:'..feed..':subs - Changing ID in set...')
	    redis:srem('rss:'..feed..':subs', 'chat#id'..old_id)
		redis:sadd('rss:'..feed..':subs', 'chat#id'..new_id)
	  end
    end
  end
  
  -- Migrate Tagesschau-Eilmeldungen
  local does_tagesschau_set_exists = redis:exists('telegram:tagesschau:subs')
  if does_tagesschau_set_exists then
	  local is_in_set = redis:sismember('telegram:tagesschau:subs', 'chat#id'..old_id)
	  if is_in_set then
	    print('telegram:tagesschau:subs - Changing ID in set...')
	    redis:srem('telegram:tagesschau:subs', 'chat#id'..old_id)
		redis:sadd('telegram:tagesschau:subs', 'chat#id'..new_id)
	  end
  end
  
  print('--- SUPERGROUP MIGRATION ENDED ---')
  utilities.send_message(new_id, 'Die ID dieser Gruppe ist nun <code>'..new_id..'</code>.\nAlle Daten wurden übertragen.', true, nil, 'HTML')
end

return migrate