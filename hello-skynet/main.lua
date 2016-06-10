local skynet = require "skynet"

skynet.start( function()
	local service1_addr = skynet.newservice("service1")
	local service2_addr = skynet.newservice("service2")

	skynet.call( service1_addr, "lua", "message_handler_1", service2_addr, "hello skynet" )
	skynet.exit()
end )
