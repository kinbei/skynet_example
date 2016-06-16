local zwproto = require "zwproto.core"

local player_info = {}
function player_info.serial( player, complete_sz )
	complete_sz = zwproto.writenumber( player.player_id, complete_sz )
	complete_sz = zwproto.writestring( player.nickname, complete_sz )
	complete_sz = zwproto.writenumber( player.sex, compelte_sz )
	complete_sz = zwproto.writenumber( player.level, complete_sz )
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

function protocol.response_serial( resp )
	local complete_sz = 0
	complete_sz = zwproto.writenumber( resp.retcode, complete_sz )
	complete_sz = zwproto.writenumber( resp.challenge_id, complete_sz )
	complete_sz = zwproto.writenumber( #resp.vecPlayers, complete_sz )
	for _, v in ipairs(resp.vecPlayers) do
		complete_sz = player_info.serial( v, complete_sz )
	end
	return zwproto.getbuffer(), complete_sz
end

return protocol
