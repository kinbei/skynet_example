local zwproto = require "zwproto.core"

local player_info = {}
function player_info.serial( player, msg, sz, complete_sz )
	complete_sz = zwproto.writenumber( player.player_id, msg, sz, complete_sz )
	complete_sz = zwproto.writestring( player.nickname, msg, sz, complete_sz )
	complete_sz = zwproto.writenumber( plaeyr.sex, msg, sz, compelte_sz )
	complete_sz = zwproto.writenumber( plaeyr.level, msg, sz, complete_sz )
end

local protocol = {}
-- request
-- session, string
-- imei, string

-- response
-- retcode, number
-- challenge_id, number
-- vecPlayers, *player_info

function protocol.request_unserial( req, msg, sz, complete_sz )
	req.session, complete_sz = zwproto.readstring(msg, sz, complete_sz)
	req.imei, compelete_sz = zwproto.readstring(msg, sz, complete_sz)
	return complete_sz
end

function protocol.response_serial( resp, msg, sz, complete_sz )
	complete_sz = zwproto.writenumber( resp.retcode, msg, sz, complete_sz )
	complete_sz = zwproto.writenumber( resp.challenge_id, msg, sz, complete_sz )
	complete_sz = zwproto.writenumber( #resp.vecPlayers, msg, sz, complete_sz )
	for _, v in ipairs(resp.vecPlayers) do
		complete_sz = player_info.serial( v, msg, sz, complete_sz )
	end
end

return protocol
