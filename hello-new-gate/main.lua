local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local zwproto = require "zwproto.core"

local function zwprotoparse(msg, sz)
	local header = {}
	local complete_sz = 0

	header.magic, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	header.version, complete_sz = zwproto.readuint8( msg, sz, complete_sz )
	header.serialno, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	header.servantname, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	header.checksum, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	header.flag, complete_sz = zwproto.readuint16( msg, sz, complete_sz )
	header.slen, complete_sz = zwproto.readuint8( msg, sz, complete_sz )
	header.llen, complete_sz = zwproto.readuint16( msg, sz, complete_sz )
	return header
end

local function req2str(header)
	local r = ""
	r = r .. string.format("header.magic = 0x%08X ", header.magic)
	r = r .. string.format("header.version = 0x%08X ", header.version)
	r = r .. string.format("header.serialno = 0x%08X ", header.serialno)
	r = r .. string.format("header.servantname = 0x%08X ", header.servantname)
	r = r .. string.format("header.checksum = 0x%08X ", header.checksum)
	r = r .. string.format("header.flag = 0x%08X ", header.flag)
	return r	
end

local function read(fd)
	return zwprotoparse( proxy.read(fd) )
end

skynet.start(function()
	skynet.newservice("debug_console",8000)

	skynet.error(string.format("Listen on 8888"))
	local id = assert(socket.listen("192.168.8.196", 8888))
	socket.start(id, function (fd, addr)
		skynet.error(string.format("%s connected as %d" , addr, fd))
		proxy.subscribe(fd)
		while true do
			local ok, req = xpcall(read, debug.traceback, fd)
			if not ok then
				skynet.error("CLOSE", req)
				break
			end

			skynet.error(req2str(req))
		end
	end)
end)
