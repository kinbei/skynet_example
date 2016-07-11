local skynet = require "skynet"

skynet.start(function()
	skynet.uniqueservice("debug_console", 8000)
	skynet.uniqueservice("watchdog")

	local cellapp = skynet.uniqueservice("cellapp")
	skynet.call(cellapp, "lua", "init", 1, 800, 800)

	skynet.exit()
end)
