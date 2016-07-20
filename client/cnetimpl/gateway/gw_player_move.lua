local function request_pack(req)
	zwproto.writesize(#req.steps)
	for _, v in ipairs(req.steps) do
		zwproto.writeuint16(v.x)
		zwproto.writeuint16(v.y)
		zwproto.writeuint16(v.z)
	end
end

return {
	request_pack = request_pack,
}
