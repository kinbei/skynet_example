local skynet = require "skynet"

skynet.start( function()
	skynet.error("Server start")
	local console = skynet.newservice("console")
	skynet.newservice("debug_console",8000)
	
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	
	skynet.error("Watchdog listen on ", 8888)
end )
