local zwproto = require "zwproto.core"

local protocol = {}

function protocol.request_unserial( req, msg, sz, complete_sz )
	return complete_sz
end

return protocol
