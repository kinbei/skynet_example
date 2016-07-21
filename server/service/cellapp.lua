local skynet = require "skynet"
local debugtools = require "debugtools"
local create_map = require "scene.map"

local CMD = {}
local map
local agent_player = {} -- agent --> player

--- Function for player

local AVATAR_TYPE_PLAYER = 1

local AVATAR_EVENT_ADD = 1
local AVATAR_EVENT_DEL = 2
local AVATAR_EVENT_MOV = 3

local function get_avatar_id(self)
	return self.avatar_common.avatar_id
end

local function gen_del_avatar_event(self)
	return {
		avatar_id = self.avatar_id,
		nickname = self.nickname,
		event_type = AVATAR_EVENT_DEL,
	}
end

local function gen_add_avatar_event(self)
	return {
		avatar_id = self.avatar_id,
		nickname = self.nickname,
		event_type = AVATAR_EVENT_ADD,
	}
end

local function gen_mov_avatar_event(self)
	return {
		avatar_id = self.avatar_id,
		nickname = self.nickname,
		event_type = AVATAR_EVENT_MOV,
	}
end

local function need_aoi_process()
	return true
end

local function push_aoi(self, event)
	self.aoi_list[#self.aoi_list + 1] = event
end

local function get_avatar_type()
	return AVATAR_TYPE_PLAYER
end

local function clear_aoi(self)
	self.aoi_list = {}
end

--- 

function CMD.init(map_id, map_width, map_height)
	map = create_map(map_id, map_width, map_height)
end

function CMD.player_online(agent, avatar_common)
	skynet.error(string.format("cellapp player_online agent(0x%08X)", agent))

	local player = {}
	player.avatar_common = avatar_common
	player.agent = agent
	player.aoi_list = {}

	player.get_avatar_id = get_avatar_id
	player.gen_del_avatar_event = gen_del_avatar_event
	player.gen_add_avatar_event = gen_add_avatar_event
	player.gen_mov_avatar_event = gen_mov_avatar_event
	player.need_aoi_process = need_aoi_process
	player.push_aoi = push_aoi
	player.get_avatar_type = get_avatar_type
	player.clear_aoi = clear_aoi
	agent_player[agent] = player

	map:add_avatar(player, player.avatar_common.map_x, player.avatar_common.map_y)
end

function CMD.player_move(agent, steps)
	skynet.error(string.format("cellapp player_move agent(0x%08X) steps(%d)", agent, #steps))
	local player = agent_player[agent]
	if player == nil then
		skynet.error(string.format("cellapp player_offline|can't found agent(0x%08X)", agent))
		return
	end

	for _, v in ipairs(steps) do
		map:mov_avatar(player, player.avatar_common.map_x, player.avatar_common.map_y, v.x, v.y)
		player.avatar_common.map_x, player.avatar_common.map_y = v.x, v.y
	end

	-- debugtools.print("playre.aoi_list = %s", #player.aoi_list)
end

function CMD.player_offline(agent)
	local player = agent_player[agent]
	if player == nil then
		skynet.error(string.format("cellapp player_offline|can't found agent(0x%08X)", agent))
		return
	end
	
	map:del_avatar(player, player.avatar_common.map_x, player.avatar_common.map_y)
	agent_player[agent] = nil
end

local function add_timer(milseconds, func)
	skynet.timeout(milseconds / 10, function()
		assert(type(func) == "function", string.format("func = %s, type(%s)", func, type(func)))
		if type(func) == "table" then
			for k, v in pairs(func) do
				print(string.format("k(%s) v(%s)", k, v))
			end
		end

		func()
		add_timer(milseconds, func)
	end)
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

	-- aoi broadcast
	add_timer(300, function()
		for agent, player in pairs(agent_player) do
			if #player.aoi_list ~= 0 then
				debugtools.print("%s", #player.aoi_list)
				skynet.send(agent, "lua", "cellapp", "aoi_event", player.aoi_list)
				player.aoi_list = {}
			end
		end
	end)
end)
