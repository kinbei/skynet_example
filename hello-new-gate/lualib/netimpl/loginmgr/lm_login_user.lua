local zwproto = require "zwproto.core"

local player_info = {}
function player_info.pack(player)
	zwproto.writeuint64(player.player_id)
	zwproto.writestring(player.nickname)
	zwproto.writenumber(player.sex)
	zwproto.writenumber(player.level)
end

local protocol = {}
-- request
-- session, string
-- imei, string

-- response
-- retcode, number
-- challenge_id, number
-- vecPlayers, *player_info

function protocol.request_unpack()
	local req = {}
	req.session = zwproto.readstring()
	req.imei = zwproto.readstring()
	return req
end

function protocol.response_pack(resp)
	zwproto.writenumber(resp.retcode)
	zwproto.writenumber(resp.challenge_id)
	zwproto.writenumber(#resp.vecPlayers)
	for _, v in ipairs(resp.vecPlayers) do
		player_info.pack(v)
	end
end

return protocol
