local skynet = require "skynet"
local socketdriver = require "socketdriver"
local netpack = require "netpack"

local SOCKET_EVENT = {
	SKYNET_SOCKET_TYPE_DATA = 1,    -- 收到数据时
	SKYNET_SOCKET_TYPE_CONNECT = 2, -- 
	SKYNET_SOCKET_TYPE_CLOSE = 3,   -- 断开连接时
	SKYNET_SOCKET_TYPE_ACCEPT = 4,  -- 接受新连接时
	SKYNET_SOCKET_TYPE_ERROR = 5,   -- 连接发生错误
	SKYNET_SOCKET_TYPE_UDP = 6,
	SKYNET_SOCKET_TYPE_WARNING = 7,
}

local socket_message = {}

socket_message[SOCKET_EVENT.SKYNET_SOCKET_TYPE_DATA] = function(id, size, data)	
	skynet.error( "SKYNET_SOCKET_TYPE_DATA" .. string.format(" id(%s) size(%s) data(%s)", id, size, netpack.tostring(data, size) ) )

	-- socketdriver.send(id, string.pack(">z", "abcd"))
	skynet.send( skynet.self(), "socket", string.pack(">z", "abcd") )
end

socket_message[SOCKET_EVENT.SKYNET_SOCKET_TYPE_CONNECT] = function(id, _ , addr)
	skynet.error( "SKYNET_SOCKET_TYPE_CONNECT" )
end

socket_message[SOCKET_EVENT.SKYNET_SOCKET_TYPE_CLOSE] = function(fd)
	skynet.error( "SKYNET_SOCKET_TYPE_CLOSE" )
end

socket_message[SOCKET_EVENT.SKYNET_SOCKET_TYPE_ACCEPT] = function(id, newid, addr)
	skynet.error( string.format("SKYNET_SOCKET_TYPE_ACCEPT newid(%s)", newid) )
	socketdriver.start( newid )
end

socket_message[SOCKET_EVENT.SKYNET_SOCKET_TYPE_ERROR] = function(id, _, err)
	skynet.error( "SKYNET_SOCKET_TYPE_ERROR" )
end

socket_message[SOCKET_EVENT.SKYNET_SOCKET_TYPE_WARNING] = function(id, size)
	skynet.error( "SKYNET_SOCKET_TYPE_WARNING" )
end

skynet.register_protocol {
	name = "socket",
	id = skynet.PTYPE_SOCKET,	-- PTYPE_SOCKET = 6
	unpack = function ( msg, sz )
		skynet.error( string.format("unpack| msg(%s) sz(%s)", msg, sz) )
		return socketdriver.unpack( msg, sz )
	end,
	pack = function ( msg, sz ) 
		skynet.error( string.format("pack| msg(%s) sz(%s)", msg, sz) )
		return msg, sz
	end,
	dispatch = function (session, source, cmd, ...)
		socket_message[cmd]( ... )
	end,
}

skynet.start( function()
	local address = "127.0.0.1"
	local port = 8888
	local listen_socket = socketdriver.listen( address, port )
	socketdriver.start( listen_socket )

	skynet.error( string.format("Listen on %s:%s, listen_socket:%s", address, port, listen_socket) )

end )
