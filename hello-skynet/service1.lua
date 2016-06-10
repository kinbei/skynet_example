local skynet = require "skynet"

local CMD = {}

function CMD.message_handler_1( addr, str )
	skynet.error( string.format("service1.message_handler_1 = %s", str) )
	skynet.call( addr, "lua", "message_handler_1", "[this string send from service1]" )
end

skynet.start( function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd])
		f(...)
	end)
end )
