package.cpath = package.cpath .. ";./lsocket/?.so"
package.path = package.path .. ";../server/lualib/?.lua"

local zwprotoc = require "zwprotoc"
local protoloader = require "protoloader"
local NETDEFINE = require "netimpl.netdefine"
local lsocket = require "lsocket"

local function sleep(ti)
	lsocket.select(nil, nil, ti)	
end

local function argcheck(cond, fmt, ...)
	if not cond then
		error(string.format(fmt or "", ...))
	end
end

_ENV = _ENV
_ENV.zwproto = zwprotoc

local client = require "client"
client.connect("192.168.8.196", 8888)

local req = {}

req.session = "robot_session_1"
req.imei = "roboto_imei"
client.write(protoloader.request_pack(NETDEFINE.LM_LOGIN_USER, req))

req = {}
req.player_id = 1
req.challenge_id = 11
req.login_ip = ""
req.is_reconnect = 0
client.write(protoloader.request_pack(NETDEFINE.GW_PLAYER_ONLINE, req))

repeat 
	req = {}
	req.steps = {}
	req.steps[#req.steps + 1] = { x = 100, y = 100, z = 100 }
	client.write(protoloader.request_pack(NETDEFINE.GW_PLAYER_MOVE, req))

	sleep(500)
until false


io.read() -- press any key to quit
