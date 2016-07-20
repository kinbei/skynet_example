local NETDEFINE = require "netimpl.netdefine"
local serialno = 0

local netimpl = {}
netimpl[NETDEFINE.LM_LOGIN_USER] = require "cnetimpl.loginmgr.lm_login_user"
netimpl[NETDEFINE.GW_PLAYER_ONLINE] = require "cnetimpl.gateway.gw_player_online"
netimpl[NETDEFINE.GW_PLAYER_MOVE] = require "cnetimpl.gateway.gw_player_move"

local function request_pack(servantname, request)
	assert( netimpl[servantname], string.format("Can't found request handler(0x%08X)", servantname) )

	zwproto.reset()
	netimpl[servantname].request_pack( request )
	local buffer = zwproto.data

	zwproto.reset()
	serialno = serialno + 1

	assert(#zwproto.data == 0)

	zwproto.writeuint32(0xC0074346) -- magic
	zwproto.writeuint8(0x00) -- version
	zwproto.writeuint32(serialno) -- serialno
	zwproto.writeuint32(servantname) -- servantname
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

	return zwproto.data
end

local function response_unpack(msg)

end

return {
	request_pack = request_pack,
	response_unpack = response_unpack,
}