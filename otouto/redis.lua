local Redis = require 'redis'
local FakeRedis = require 'fakeredis'
local config = require('config')
if not config.redis then -- Please update the values in the config.lua!
  config.redis = {
	host = '127.0.0.1',
	port = 6379,
	use_socket = false
  }
end

-- Overwrite HGETALL
Redis.commands.hgetall = Redis.command('hgetall', {
  response = function(reply, command, ...)
    local new_reply = { }
    for i = 1, #reply, 2 do new_reply[reply[i]] = reply[i + 1] end
    return new_reply
  end
})

local redis = nil

-- Won't launch an error if fails
local ok = pcall(function()
  if config.redis.use_socket and config.redis.socket_path then
    redis = Redis.connect(config.redis.socket_path)
  else
	local params = {
	  host = config.redis.host,
	  port = config.redis.port
	}
    redis = Redis.connect(params)
  end
end)

if not ok then

  local fake_func = function()
    print('\27[31mCan\'t connect with Redis, install/configure it!\27[39m')
  end
  fake_func()
  fake = FakeRedis.new()

  redis = setmetatable({fakeredis=true}, {
  __index = function(a, b)
    if b ~= 'data' and fake[b] then
      fake_func(b)
    end
    return fake[b] or fake_func
  end })

else
  if config.redis.password then
    redis:auth(config.redis.password)
  end
  if config.redis.database then
    redis:select(config.redis.database)
  end
end


return redis