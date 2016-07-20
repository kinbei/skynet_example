local lsocket = require "lsocket"

local socket = {}
local fd
local message

local function report(fmt, ...)
	error(string.format(fmt, ...))
end

function socket.connect(addr, port)
	assert(fd == nil)
	local errmsg
	fd, errmsg = lsocket.connect(addr, port)
	if fd == nil then
		report("connect %s:%d(errmsg = %s)", addr, port, errmsg)
	end
	message = ""

	lsocket.select(nil, {fd})
	local ok, errmsg = fd:status()
	if not ok then
		report("connect: %s", errmsg)
	end
end

function socket.isconnect(ti)
	local rd, wt = lsocket.select(nil, {fd}, ti)
	return next(wt) ~= nil
end

function socket.close()
	fd:close()
	fd = nil
	message = nil
end

-- func(message)
-- message is all of the recv data
-- the return value of this function
-- c means continue process ?
-- l is the length of the recv data that func(..) hava been process
function socket.read(ti, func)
	local c, l
	c, l = func(message)

	while c do
		local rd = lsocket.select {fd, ti}
		if next(fd) == nil then
			return nil
		end
		local p = fd:recv()
		if not p then
			report("Error when read")
		end
		message = message .. p

		c, l = func(message)
	end

	local r = message:sub(1, l)
	message = message:sub(l+1)
	return r
end

function socket.write(msg)
	repeat
		local bytes = fd:send(msg)
		if not bytes then
			report("Error when write")
		end
		msg = msg:sub(bytes+1)
	until msg == ""
end

return socket