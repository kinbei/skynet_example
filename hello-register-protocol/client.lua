local skynet = require "skynet"
local socket = require "socket"

function _read(id)
    while true do
        local str = socket.read(id)
        if str then
            skynet.error(id, "server says: ", str)
            socket.close(id)
            skynet.exit()
        else
            socket.close(id)
            skynet.error("disconnected")
            skynet.exit()
        end
    end
end

skynet.start(function()
    local addr = "127.0.0.1:8888"
    local id = socket.open(addr)
    if not id then
        skynet.error("can't connect to "..addr)
        skynet.exit()
    end

    skynet.error("connected")
    skynet.fork(_read, id)
    socket.write(id, "hello socketdriver")
end)
