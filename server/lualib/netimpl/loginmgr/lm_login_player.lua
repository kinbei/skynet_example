local zwproto = require "zwproto.core"

local protocol = {}

function protocol.request_unpack()
	local req = {}
	req.player_id = zwproto.readuint64()
	req.session = zwproto.readstring()
	req.challenge_id = zwproto.readnumber()
	return req
end

function protocol.response_pack(resp)
	zwproto.writenumber(resp.retcode)
	zwproto.writestring(resp.connproxy_ip)
	zwproto.writenumber(resp.connproxy_port)
	zwproto.writestring(resp.voicemgr_ip)
	zwproto.writenumber(resp.voicemgr_port)
	zwproto.writenumber(resp.player_id)
end

return protocol