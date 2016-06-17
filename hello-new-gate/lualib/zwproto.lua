local zwproto = require "zwproto.core"
local NETDEFINE = require "netimpl.netdefine"

local netimpl = {}
netimpl[ NETDEFINE.HEARTBEAT ] = require "netimpl.system.heartbeat"
netimpl[ NETDEFINE.LM_LOGIN_USER ] = require "netimpl.loginmgr.lm_login_user"

local function request_unpack(msg, sz)
	local request = {}
	local complete_sz = 0

	request.magic, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	request.version, complete_sz = zwproto.readuint8( msg, sz, complete_sz )
	request.serialno, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	request.servantname, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	request.checksum, complete_sz = zwproto.readuint32( msg, sz, complete_sz )
	request.flag, complete_sz = zwproto.readuint16( msg, sz, complete_sz )
	request.slen, complete_sz = zwproto.readuint8( msg, sz, complete_sz )
	request.llen, complete_sz = zwproto.readuint16( msg, sz, complete_sz )

	if not netimpl[ request.servantname ] then
		error( string.format("Can't found the corresponding servantname of request parser") )
	end
	netimpl[ request.servantname ].request_unserial( request, msg, sz, complete_sz )

	return request
end

-- return buffer
local function response_pack(servantname, response)
	local complete_sz = 0
	assert( netimpl[servantname], string.format("Can't found response handler(0x%08X)", servantname) )
	local buffer = netimpl[servantname].response_pack( response, complete_sz )
	
	complete_sz = 0
	complete_sz = zwproto.writeuint32( 0xC0000001, complete_sz ) -- magic
	complete_sz = zwproto.writeuint8( 0x00, complete_sz ) -- version
	complete_sz = zwproto.writeuint32( 0x00, complete_sz ) -- serialno
	complete_sz = zwproto.writeuint32( 0x80000000 | servantname, complete_sz ) -- servantname
	complete_sz = zwproto.writeuint32( 0x00, complete_sz ) -- checksum
	complete_sz = zwproto.writeuint16( 0x00, complete_sz ) -- flag
	local sz = string.len(buffer)
	if sz < 0xFF then
		complete_sz = zwproto.writeuint8(sz, complete_sz)
	else
		complete_sz = zwproto.writeuint8(0xFF, compelte_sz)
		complete_sz = zwproto.writeuint16(sz, compelte_sz)
	end
	complete_sz = zwproto.writebytes(buffer, complete_sz)
	return zwproto.getbuffer(complete_sz)
end

return {
	request_unpack = request_unpack,
	response_pack = response_pack,
}
