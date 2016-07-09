local zwproto = require "zwproto.core"

local protocol = {}

function protocol.request_unpack()
	local req = {}
	req.nick_name = zwproto.readstring()
	req.profession_id = zwproto.readuint32()
	req.sex = zwproto.readuint32()
	return req
end

function protocol.response_pack(resp)
	zwproto.writeuint32(resp.retcode)
	zwproto.writeuint64(resp.player_id)
end

return protocol