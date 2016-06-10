local skynet = require "skynet"
local socket = require "socket"

local function echo( client_id, addr )
	socket.start( client_id )
	while true do
		local str = socket.read( client_id )
		if str then
			skynet.error( "client:" .. client_id .. " says " .. str )
			socket.write( client_id, str )
		else
			socket.close( client_id )
			skynet.error( "client:" .. client_id .. " disconnected " )
			return 
		end
	end
end

skynet.start( function()
	local listen_id = socket.listen( "127.0.0.1:8000" ) 

	socket.start( listen_id, function( client_id, addr )
		skynet.error( "client:" .. client_id .. " addr[" .. addr .. "] connected" )
		skynet.fork( echo, client_id, addr )
	end )
end )
