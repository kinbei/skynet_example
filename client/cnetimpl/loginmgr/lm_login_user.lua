local function request_pack(req)
	zwproto.writestring(req.session)
	zwproto.writestring(req.imei)
end

return {
	request_pack = request_pack,
}
