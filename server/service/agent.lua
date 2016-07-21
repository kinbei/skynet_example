local skynet = require "skynet"
local NETDEFINE = require "netimpl.netdefine"
local debugtools = require "debugtools"
local ERRCODE = require "netimpl.errcode"

local CMD = {}
local CLIENT = {}
local CELLAPP = {}
local cellapp

-- init in CMD.init
local avatar_common
local client_fd

CLIENT[NETDEFINE.GW_PLAYER_MOVE] = function(fd, req, header)
	local steps = {}
	for _, v in ipairs(req.steps) do
		steps[#steps+1] = { x = v.x, y = v.z }
	end
	
	-- local s = ""
	-- for _, step in ipairs(req.steps) do
	--	s = s .. string.format("{x=%d, y=%d, z=%d} ", step.x, step.y, step.z)
	-- end
	-- skynet.error(string.format("gw_player_move|player_id(%d) steps(%s)", avatar_common.avatar_id, s))

	skynet.call(cellapp, "lua", "player_move", skynet.self(), steps)
	avatar_common.map_x = steps[#steps].x
	avatar_common.map_y = steps[#steps].z

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	return resp
end

function CMD.init(conf)
	skynet.error("agent init")
	local fd = conf.fd
	local watchdog = conf.watchdog
	avatar_common = conf.avatar_common
	client_fd = fd

	skynet.call(cellapp, "lua", "player_online", skynet.self(), avatar_common)
end

function CMD.client(fd, req, header)
	local f = CLIENT[header.servantname]
	if f == nil then
		-- debugtools.print(string.format("servantname(0x%08X) agent donothing", header.servantname))
	else
		return f(fd, req, header)
	end
end

function CMD.cellapp(command, ...)
	local f = CELLAPP[command]
	if f == nil then
		debugtools.print("cellapp command = %s not found", command)
	else
		return f(...)
	end
end

function CELLAPP.aoi_event(aoi_list)
	debugtools.print("cellapp aoi list %d", #aoi_list)
end

skynet.start( function()
	skynet.dispatch("lua", function(_, _, command, ...)
		local f = CMD[command]
		if f == nil then
			debugtools.print("command = %s not found", command)
		else
			skynet.ret(skynet.pack(f(...)))
		end
	end)

	cellapp = skynet.uniqueservice("cellapp")
end)
