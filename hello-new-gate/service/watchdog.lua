local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local zwproto = require "zwproto"
local NETDEFINE = require "netimpl.netdefine"
local ERRCODE = require "netimpl.errcode"
local print_r = require "print_r"

local socket_agent = {} -- fd --> agent

local function read(fd)
	return zwproto.unpack_request( proxy.read(fd) )
end

local CMD = {}

CMD[NETDEFINE.HEARTBEAT] = function()
	skynet.error( "heartbeat" )
end

CMD[NETDEFINE.LM_LOGIN_USER] = function(fd, request)
	skynet.error( string.format("lm_login_user|session(%s) imei(%s)", request.session, request.imei) )

	local resp = {}
	resp.retcode = ERRCODE.SUCCESS
	resp.challenge_id = 12345
	resp.vecPlayers = {}
	table.insert( resp.vecPlayers, { player_id = 12345, nickname = "nickname", sex = 1, level = 100 } )
end

skynet.start( function()
	skynet.error(string.format("Listen on 8888"))
	
	local listen_socket = assert(socket.listen("192.168.8.196", 8888))
	socket.start(listen_socket, function (fd, addr)
		skynet.error(string.format("%s connected as %d" , addr, fd))
		proxy.subscribe(fd)
		while true do
			local ok, req = xpcall(read, debug.traceback, fd)
			if not ok then
				-- Todo if agent exist, notify agent close
				skynet.error("CLOSE", req)
				break
			end
			
			if socket_agent[fd] ~= nil then
				
			else
				if CMD[req.servantname] == nil then
					skynet.error( string.format("Unknown servantname(0x%08X) close connection", req.servantname) )
					proxy.close(fd) -- Close connection of client
					break
				end
				CMD[req.servantname](fd, req)
				-- Todo send response to client
			end
		end
	end)
end)
