local skynet = require "skynet"

skynet.start( function()
	skynet.newservice("mysqldb")
	skynet.exit()
end )
