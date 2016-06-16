local zwproto = require "zwproto.core"
local NETDEFINE = require "netimpl.netdefine"

local netimpl = {}
netimpl[ NETDEFINE.HEARTBEAT ] = require "netimpl.system.heartbeat"
netimpl[ NETDEFINE.LM_LOGIN_USER ] = require "netimpl.loginmgr.lm_login_user"

local function zwproto_parse_request(msg, sz)
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

local function zwproto_pack_response(servantname, response)
	local complete_sz = 0
	complete_sz = zwproto.writeuint32( 0xC0121212, compelte_sz ) -- magic
	complete_sz = zwproto.writeuint8( 0x00, complete_sz ) -- version
	complete_sz = zwproto.writeuint32( 0x00, complete_sz ) -- serialno
	complete_sz = zwproto.writeuint32( 0x80000000 | servantname, complete_sz ) -- servantname
	complete_sz = zwproto.writeuint32( 0x00, complete_sz ) -- checksum
	complete_sz = zwproto.writeuint16( 0x00, complete_sz ) -- flag
	

end

return {
	unpack_request = zwproto_parse_request,
	pack_response = zwproto_pack_response,
}
