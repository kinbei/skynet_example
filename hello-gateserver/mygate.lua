local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local netpack = require "netpack"
local socketdriver = require "socketdriver"

local handler = {}

function handler.message(fd, msg, sz)
	skynet.error( string.format("socket message fd(%s) msg(%s) sz(%d) context(%s)", fd, msg, sz, netpack.tostring(msg, sz)) )
	socketdriver.send(fd, string.pack(">z", "hello client, this is mygate"))
end

function handler.connect(fd, addr)
	skynet.error( string.format("socket new client fd(%s) addr(%s)", fd, addr) )
	gateserver.openclient(fd)
end

function handler.open(source, conf)
	skynet.error( string.format("begin listening on %s:%d", conf.address, conf.port) )
end

function handler.disconnect(fd)
	skynet.error( string.format("socket disconnect: fd(%s)", fd) )
	gateserver.closeclient(fd)
end

function handler.error(fd, msg)
	skynet.error( string.format("socket error: fd(%s) msg(%s)", fd, msg) )
	gateserver.closeclient(fd)
end

function handler.warning(fd, msg)
	skynet.error( string.format("socket error: fd(%s) msg(%s)", fd, msg) )
	gateserver.closeclient(fd)	
end

local CMD = {}

function handler.command(cmd, address, ...)
	local f = assert( CMD[cmd] )
	return f( address, ... )
end

gateserver.start(handler)
