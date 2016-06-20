local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local zwproto = require "zwproto"
local NETDEFINE = require "netimpl.netdefine"
local ERRCODE = require "netimpl.errcode"

local socket_agent = {} -- fd --> agent
local CMD = {}

CMD[NETDEFINE.HEARTBEAT] = function()
	skynet.error( "heartbeat" )
end

CMD[NETDEFINE.LM_LOGIN_USER] = function(fd, request)
	skynet.error( string.format("lm_login_user|session(%s) imei(%s)", request.session, request.imei) )

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	resp.challenge_id = 0xFFFFFFFF
	resp.vecPlayers = {}
	table.insert( resp.vecPlayers, { player_id = 12345, nickname = "nickname", sex = 1, level = 100 } )
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
					skynet.error( string.format("Unknown servantname(0x%08X) close connection", header.servantname) )
					proxy.close(fd) -- Close connection of client
					break
				end
				local resp = CMD[header.servantname](fd, req)
				if resp then
					socket.write(fd, zwproto.response_pack( header.servantname, resp ))
				end
			end
		end
	end)
end)
