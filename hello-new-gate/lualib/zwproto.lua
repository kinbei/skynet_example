local zwproto = require "zwproto.core"
local NETDEFINE = require "netimpl.netdefine"

local netimpl = {}
netimpl[ NETDEFINE.HEARTBEAT ] = require "netimpl.system.heartbeat"
netimpl[ NETDEFINE.LM_LOGIN_USER ] = require "netimpl.loginmgr.lm_login_user"

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
		error( string.format("Can't found the corresponding servantname(0x%08X) of request parser", header.servantname) )
	end
	return netimpl[ header.servantname ].request_unserial(), header
end

-- return buffer
local function response_pack(servantname, response)
	assert( netimpl[servantname], string.format("Can't found response handler(0x%08X)", servantname) )
	zwproto.resetwritebuffer(0)
	netimpl[servantname].response_pack( response )
	local buffer = zwproto.getwritebuffer(complete_sz)

	zwproto.resetwritebuffer(0)
	zwproto.writeuint32(0xC0074346) -- magic
	zwproto.writeuint8(0x00) -- version
	zwproto.writeuint32(0x00) -- serialno
	zwproto.writeuint32(0x80000000 | servantname) -- servantname
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
