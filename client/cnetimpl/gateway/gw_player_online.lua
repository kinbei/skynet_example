local function request_pack(req)
	zwproto.writeuint64(req.player_id)
	zwproto.writenumber(req.challenge_id)
	zwproto.writestring(req.login_ip)
	zwproto.writenumber(req.is_reconnect)
end

return {
	request_pack = request_pack,
}
