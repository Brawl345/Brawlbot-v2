local entergroup = {}

entergroup.triggers = {
  '/nil'
}

function entergroup:chat_new_user(msg, self)
  local user_name = msg.new_chat_member.first_name
  local chat_title = msg.chat.title
  if msg.from.username then
    at_name = ' (@'..msg.from.username..')'
  else
    at_name = ''
  end
  if msg.from.id == msg.new_chat_member.id then -- entered through link
    added_by = ''
  else
    added_by = '\n'..msg.from.name..at_name..' hat dich hinzugefügt!'
  end
  if msg.new_chat_member.id == self.info.id then -- don't say hello to ourselves
    return
  end
  local text = 'Hallo '..user_name..', willkommen bei *'..chat_title..'*!'..added_by
  utilities.send_reply(self, msg, text, true)
end

function entergroup:chat_del_user(msg, self)
  if msg.left_chat_member.id == msg.from.id then -- silent ignore, if user wasn't kicked
    return
  end
  local user_name = msg.left_chat_member.first_name
  if msg.from.username then
    at_name = ' (@'..msg.from.username..')'
  else
    at_name = ''
  end
  local text = user_name..' wurde von '..msg.from.first_name..at_name..' aus der Gruppe gekickt.'
  utilities.send_reply(self, msg, text, true)
end

function entergroup:pre_process(msg, self)
  if msg.new_chat_member then
    entergroup:chat_new_user(msg, self)
  elseif msg.left_chat_member then
    entergroup:chat_del_user(msg, self)
  end

  return msg
end

function entergroup:action(msg)
end

return entergroup
