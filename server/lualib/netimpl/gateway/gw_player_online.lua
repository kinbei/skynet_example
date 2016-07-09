local zwproto = require "zwproto.core"

local function write_through(func, value, times)
	for i = 1, times do
		func(value)
	end
end

local avatar_common = {}
function avatar_common.pack(common)
	zwproto.writeuint64(common.avatar_id)
	zwproto.writenumber(common.avatar_type)
	zwproto.writenumber(common.object_id)
	zwproto.writenumber(common.sex)
	zwproto.writenumber(common.profession)
	zwproto.writenumber(common.level)
	zwproto.writenumber(common.map_x)
	zwproto.writenumber(common.map_y)
	zwproto.writenumber(common.map_z)
	zwproto.writenumber(common.direction)
	zwproto.writestring(common.nick_name)
	write_through(zwproto.writenumber, 0, 8)
	write_through(zwproto.writestring, "", 1)
	write_through(zwproto.writenumber, 0, 7)
end

local avatar_detail = {}
function avatar_detail.pack(detail)
	write_through(zwproto.writeuint8, 0, 3)
	write_through(zwproto.writeuint16, 0, 1)
	write_through(zwproto.writeuint32, 0, 3)
	write_through(zwproto.writeuint8, 0, 1)
	write_through(zwproto.writeuint32, 0, 1)
	write_through(zwproto.writestring, "", 1)
	write_through(zwproto.writeuint32, 0, 3)
	write_through(zwproto.writenumber, 0, 8)
	write_through(zwproto.writestring, "", 2)
	write_through(zwproto.writeuint32, 0, 2)
	write_through(zwproto.writeuint64, 0, 1)
	write_through(zwproto.writeuint32, 0, 4)
	write_through(zwproto.writeuint8, 0, 1)
	write_through(zwproto.writeuint64, 0, 2)
	write_through(zwproto.writeuint8, 0, 2)
	write_through(zwproto.writeuint32, 0, 6)
	write_through(zwproto.writeuint8, 0, 1)
	write_through(zwproto.writestring, "", 1)
	write_through(zwproto.writeuint32, 0, 1)
	write_through(zwproto.writenumber, 0, 29)
	write_through(zwproto.writeuint64, 0, 1)
	write_through(zwproto.writenumber, 0, 8)
end

local protocol = {}

function protocol.request_unpack()
	local req = {}
	req.player_id = zwproto.readuint64()
	req.challenge_id = zwproto.readnumber()
	req.login_ip = zwproto.readstring()
	req.is_reconnect = zwproto.readnumber()
	return req
end

function protocol.response_pack(resp)
	zwproto.writeuint32(resp.retcode) -- 
	avatar_common.pack(resp.avatar_common) -- 
	avatar_detail.pack()
	write_through(zwproto.writenumber, 0, 1)
	write_through(zwproto.writesize, 0, 8)
	write_through(zwproto.writeuint32, 0, 1)
	write_through(zwproto.writesize, 0, 1)
	write_through(zwproto.writeuint32, 0, 1)
	write_through(zwproto.writeuint16, 0, 1)
	write_through(zwproto.writestring, "", 1)
	write_through(zwproto.writeuint8, 0, 1)
	write_through(zwproto.writeuint32, 0, 3)
	write_through(zwproto.writesize, 0, 8)
	zwproto.writenumber(resp.current_map_id) -- 
	write_through(zwproto.writenumber, 0, 13)
	zwproto.writenumber(resp.open_server_date) -- 
	write_through(zwproto.writenumber, 0, 13)
	write_through(zwproto.writenumber, 0, 5)
	zwproto.writenumber(resp.create_player_time) --
	write_through(zwproto.writenumber, 0, 6)
end

return protocol