local zwproto = require "zwproto.core"

local protocol = {}

function protocol.request_unpack()
	local req = {}
	zwproto.readuint32()

	local count = zwproto.readsize()
	req.steps = {}
	for i = 1, count do
		local step = {}
		step.x = zwproto.readuint16()
		step.y = zwproto.readuint16()
		step.z = zwproto.readuint16()
		req.steps[i] = step
	end

	return req
end

function protocol.response_pack(resp)
	zwproto.writeuint32(resp.retcode)
end

return protocol