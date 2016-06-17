local skynet = require "skynet"

local debugtools = {}

function debugtools.print( fmt, ... )
	skynet.error( "[DEBUG]" .. string.format( fmt, ... ) )
end

function debugtools.dumphex(bytes)
  return string.gsub(bytes, ".", function(x) return string.format("%02x ", string.byte(x)) end)
end

return debugtools
