local skynet = require "skynet"
require "skynet.manager"	-- import skynet.abort

skynet.start( function()
	skynet.error("hello world")
	skynet.abort()
	skynet.exit()
end )
