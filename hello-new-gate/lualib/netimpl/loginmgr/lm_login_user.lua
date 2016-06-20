local zwproto = require "zwproto.core"
local skynet = require "skynet"

local player_info = {}
function player_info.serial(player)
	zwproto.writenumber(player.player_id)
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

function protocol.request_unserial()
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
		player_info.serial(v)
	end
end

return protocol
