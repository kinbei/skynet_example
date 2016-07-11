local zwproto = require "zwproto.core"

local protocol = {}

function protocol.request_unpack()
	local req = {}
	zwproto.readuint32()

	local count = zwproto.readsize()
	req.steps = {}

	assert(req.steps)
	for i = 1, count do
		assert(req.steps)

		local step = {}
		step.x = zwproto.readuint16()
		step.y = zwproto.readuint16()
		step.z = zwproto.readuint16()

		assert(req.steps)
		assert(i)
		req.steps[i] = step
	end

	return req
end

function protocol.response_pack(resp)
	zwproto.writeuint32(resp.retcode)
end

return protocol