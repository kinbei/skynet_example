local skynet = require "skynet"

skynet.start( function()
	local mygate = skynet.newservice("mygate")

	skynet.call(mygate, "lua", "open", {
	    address = "127.0.0.1", -- 监听地址 127.0.0.1
	    port = 12345,    -- 监听端口 8888
	    maxclient = 1024,   -- 最多允许 1024 个外部连接同时建立
	    nodelay = true,     -- 给外部连接设置  TCP_NODELAY 属性
	})

	skynet.exit()
end )
