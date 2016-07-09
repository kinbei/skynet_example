local skynet = require "skynet"
local NETDEFINE = require "netimpl.netdefine"
local debugtools = require "debugtools"

local CMD = {}
local CLIENT = {}

-- init in CMD.init
local avatar_common
local client_fd

CLIENT[NETDEFINE.GW_PLAYER_MOVE] = function(fd, req, header)
	local s = ""
	for _, step in ipairs(req.steps) do
		s = s .. string.format("{x=%d, y=%d, z=%d} ", step.x, step.y, step.z)
	end
	skynet.error(string.format("gw_player_move|player_id(%d) steps(%s)", avatar_common.avatar_id, s))
end


function CMD.init(conf)
	skynet.error("agent init")
	local fd = conf.fd
	local watchdog = conf.watchdog
	avatar_common = conf.avatar_common
	client_fd = fd
end

function CMD.client(fd, req, header)
	local f = CLIENT[header.servantname]
	if f == nil then
		-- debugtools.print(string.format("servantname(0x%08X) agent donothing", header.servantname))
	else
		return f(fd, req, header)
	end
end

skynet.start( function()
	skynet.dispatch("lua", function(_, _, command, ...)
		local f = CMD[command]
		if f == nil then
			debugtools.print("command = %s", command)
		else
			skynet.ret(skynet.pack(f(...)))
		end
	end)
end)
