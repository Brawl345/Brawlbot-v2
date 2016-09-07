--[[
    bindings.lua (rev. 2016/08/20)
    otouto's bindings for the Telegram bot API.
    https://core.telegram.org/bots/api
    See the "Bindings" section of README.md for usage information.

    Copyright 2016 topkecleon <drew@otou.to>

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Affero General Public License version 3 as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License
    for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program; if not, write to the Free Software Foundation,
    Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
]]--

local bindings = {}

local https = require('ssl.https')
https.TIMEOUT = 10
local json = require('dkjson')
local ltn12 = require('ltn12')
local mp_encode = require('multipart-post').encode

function bindings.init(token)
    bindings.BASE_URL = 'https://api.telegram.org/bot' .. token .. '/'
    return bindings
end

 -- Build and send a request to the API.
 -- Expecting self, method, and parameters, where method is a string indicating
 -- the API method and parameters is a key/value table of parameters with their
 -- values.
 -- Returns the table response with success. Returns false and the table
 -- response with failure. Returns false and false with a connection error.
 -- To mimic old/normal behavior, it errs if used with an invalid method.
function bindings.request(method, parameters, file)
	parameters = parameters or {}
	for k,v in pairs(parameters) do
		parameters[k] = tostring(v)
	end
	if file and next(file) ~= nil then
	    local file_type, file_name = next(file)
		if not file_name then return false end
	    if string.match(file_name, '/tmp/') then
		  local file_file = io.open(file_name, 'r')
		  local file_data = {
	  		filename = file_name,
			data = file_file:read('*a')
		  }
		  file_file:close()
		  parameters[file_type] = file_data
		else
		  local file_type, file_name = next(file)
		  parameters[file_type] = file_name
		end
	end
	if next(parameters) == nil then
		parameters = {''}
	end
	local response = {}
	local body, boundary = mp_encode(parameters)
	local success, code = https.request{
		url = bindings.BASE_URL .. method,
		method = 'POST',
		headers = {
			["Content-Type"] =	"multipart/form-data; boundary=" .. boundary,
			["Content-Length"] = #body,
		},
		source = ltn12.source.string(body),
		sink = ltn12.sink.table(response)
	}
	local data = table.concat(response)
	if not success then
		print(method .. ': Connection error. [' .. code  .. ']')
		return false, false
	else
		local result = json.decode(data)
		if not result then
			return false, false
		elseif result.ok then
			return result
		else
			assert(result.description ~= 'Method not found', method .. ': Method not found.')
			return false, result
		end
	end
end

function bindings.gen(_, key)
	return function(params, file)
		return bindings.request(key, params, file)
	end
end
setmetatable(bindings, { __index = bindings.gen })

return bindings