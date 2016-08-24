local hello = {}

hello.triggers = {
  "^[Ss][Aa][Gg] [Hh][Aa][Ll][Ll][Oo] [Zz][Uu] (.*)$"
}

function hello:action(msg, config, matches)
  utilities.send_message(msg.chat.id, 'Hallo, '..matches[1]..'!')
end

return hello
