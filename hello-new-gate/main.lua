local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"

local strgsub = string.gsub
local strformat = string.format
local strbyte = string.byte

local function _dumphex(bytes)
  return strgsub(bytes, ".", function(x) return strformat("%02x ", strbyte(x)) end)
end

local function read(fd)
	return skynet.tostring(proxy.read(fd))
end

skynet.start(function()
	skynet.newservice("debug_console",8000)

	skynet.error(string.format("Listen on 8888"))
	local id = assert(socket.listen("192.168.8.196", 8888))
	socket.start(id, function (fd, addr)
		skynet.error(string.format("%s connected as %d" , addr, fd))
		proxy.subscribe(fd)
		while true do
			skynet.error("read new message now")
			local ok, s = pcall(read, fd)
			if not ok then
				skynet.error("CLOSE")
				break
			end
			if s == "quit" then
				proxy.close(fd)
				break
			end
			skynet.error(_dumphex(s))
		end
	end)
end)
