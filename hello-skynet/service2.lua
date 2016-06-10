local skynet = require "skynet"

local CMD = {}

function CMD.message_handler_1( str )
	skynet.error( string.format("service2.message_handler_1 = %s", str) )
end

skynet.start( function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd])
		f(...)
	end)
end )
