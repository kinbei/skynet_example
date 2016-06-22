local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local zwproto = require "zwproto"
local NETDEFINE = require "netimpl.netdefine"
local ERRCODE = require "netimpl.errcode"
local debugtools = require "debugtools"

local socket_agent = {} -- fd --> agent
local CMD = {}
local player_id = 0

CMD[NETDEFINE.HEARTBEAT] = function()
	-- skynet.error( "heartbeat" )
end

CMD[NETDEFINE.LM_LOGIN_USER] = function(fd, request)
	skynet.error( string.format("lm_login_user|session(%s) imei(%s)", request.session, request.imei) )
	player_id = player_id + 1

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	resp.challenge_id = 0xFFFFFFFF
	resp.vecPlayers = {}
	table.insert( resp.vecPlayers, { player_id = player_id, nickname = string.format("nickname-%d", player_id), sex = 1, level = 100 } )

	debugtools.print( "player_id(%d) nickname(%s) sex(%d) level(%d)", resp.vecPlayers[1].player_id, resp.vecPlayers[1].nickname, resp.vecPlayers[1].sex, resp.vecPlayers[1].level )
	return resp
end

CMD[NETDEFINE.LM_LOGIN_PLAYER] = function(fd, request)
	skynet.error( string.format("lm_login_player|player_id(%d) session(%s) challenge_id(%d)", request.player_id, request.session, request.challenge_id) )

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	resp.connproxy_ip = "192.168.8.196"
	resp.connproxy_port = 8888
	resp.voicemgr_ip = "192.168.8.196"
	resp.voicemgr_port = 8888
	resp.player_id = request.player_id
	return resp
end

CMD[NETDEFINE.LM_CREATE_PLAYER] = function(fd, request)
	skynet.error( string.format("lm_create_player|nickname(%s) profession_id(%d) sex(%d)", request.nick_name, request.profession_id, request.sex) )
	player_id = player_id + 1

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	resp.player_id = player_id
	return resp
end

CMD[NETDEFINE.GW_PLAYER_ONLINE] = function(fd, request)
	skynet.error( string.format("gw_player_online|player_id(%d) challenge_id(%d)", request.player_id, request.challenge_id) )

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	resp.avatar_common = {}
	resp.avatar_common.avatar_id = request.player_id
	resp.avatar_common.avatar_type = 0
	resp.avatar_common.object_id = 0
	resp.avatar_common.sex = 1
	resp.avatar_common.profession = 1
	resp.avatar_common.level = 10
	resp.avatar_common.map_x = 142
	resp.avatar_common.map_y = 142
	resp.avatar_common.map_z = 142
	resp.avatar_common.direction = 0
	resp.avatar_common.nick_name = string.format("nickname-%d", request.player_id)
	resp.current_map_id = 1
	resp.open_server_date = os.time()
	resp.create_player_time = os.time()
	return resp
end

local function get_request(fd)
	return zwproto.request_unpack( proxy.read(fd) )
end

skynet.start( function()
	skynet.error(string.format("Listen on 8888"))
	
	local listen_socket = assert(socket.listen("192.168.8.196", 8888))
	socket.start(listen_socket, function (fd, addr)
		skynet.error(string.format("%s connected as %d" , addr, fd))
		proxy.subscribe(fd)
		while true do
			local ok, req, header = xpcall(get_request, debug.traceback, fd)
			if not ok then
				-- Todo if agent exist, notify agent close
				skynet.error("CLOSE", req)
				break
			end
			
			if socket_agent[fd] ~= nil then
				
			else
				if CMD[header.servantname] == nil then
					skynet.error( string.format("servantname(0x%08X) donothing", header.servantname) )
					-- skynet.error( string.format("Unknown servantname(0x%08X) close connection", header.servantname) )
					-- proxy.close(fd) -- Close connection of client
					-- break
				else
					local resp = CMD[header.servantname](fd, req)
					if resp then
						local buff = zwproto.response_pack( header, resp )
						-- debugtools.print( "response to client" )
						-- debugtools.print( debugtools.dumphex(buff) )
						socket.write(fd, buff)
					end
				end
			end
		end
	end)
end)
