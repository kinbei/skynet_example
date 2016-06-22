local zwproto = require "zwproto.core"
local NETDEFINE = require "netimpl.netdefine"

local netimpl = {}
netimpl[ NETDEFINE.HEARTBEAT ] = require "netimpl.system.heartbeat"
netimpl[ NETDEFINE.LM_LOGIN_USER ] = require "netimpl.loginmgr.lm_login_user"
netimpl[ NETDEFINE.LM_LOGIN_PLAYER ] = require "netimpl.loginmgr.lm_login_player"
netimpl[ NETDEFINE.LM_CREATE_PLAYER ] = require "netimpl.loginmgr.lm_create_player"
netimpl[ NETDEFINE.GW_PLAYER_ONLINE ] = require "netimpl.gateway.gw_player_online"

local function request_unpack(msg, sz)
	local header = {}
	zwproto.resetreadbuffer(msg, sz, 0)

	header.magic = zwproto.readuint32()
	header.version = zwproto.readuint8()
	header.serialno = zwproto.readuint32()
	header.servantname = zwproto.readuint32()
	header.checksum = zwproto.readuint32()
	header.flag = zwproto.readuint16()
	header.slen = zwproto.readuint8()
	header.llen = zwproto.readuint16()

	if not netimpl[ header.servantname ] then
		-- error( string.format("Can't found the corresponding servantname(0x%08X) of request parser", header.servantname) )
		return require("netimpl.system.empty").request_unpack(), header
	end
	return netimpl[ header.servantname ].request_unpack(), header
end

-- return buffer
local function response_pack(header, response)
	if netimpl[header.servantname] == nil then
		return ""
	end

	assert( netimpl[header.servantname], string.format("Can't found response handler(0x%08X)", header.servantname) )
	zwproto.resetwritebuffer(0)
	netimpl[header.servantname].response_pack( response )
	local buffer = zwproto.getwritebuffer(complete_sz)

	zwproto.resetwritebuffer(0)
	zwproto.writeuint32(0xC0074346) -- magic
	zwproto.writeuint8(0x00) -- version
	zwproto.writeuint32(header.serialno) -- serialno
	zwproto.writeuint32(0x80000000 | header.servantname) -- servantname
	zwproto.writeuint32(0x00) -- checksum
	zwproto.writeuint16(0x00) -- flag
	
	local sz = string.len(buffer)
	if sz < 0xFF then
		zwproto.writeuint8(sz)
	else
		zwproto.writeuint8(0xFF)
		zwproto.writeuint16(sz)
	end
	zwproto.writebytes(buffer)
	return zwproto.getwritebuffer()
end

return {
	request_unpack = request_unpack,
	response_pack = response_pack,
}
