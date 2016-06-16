local skynet = require "skynet"

skynet.start(function()
	skynet.uniqueservice("debug_console", 8000)
	skynet.uniqueservice("watchdog")
	skynet.exit()
end)
