local skynet = require "skynet"

skynet.start( function()
	skynet.newservice("service1")
	skynet.exit()
end )
