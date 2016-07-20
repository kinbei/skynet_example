local zwproto = {}
zwproto.data = ""

-- cond is condition
-- fmt is the format of error message
local function argcheck(cond, fmt, ...)
	if not cond then
		error(string.format(fmt, ...))
	end
end

function zwproto.reset(data)
	zwproto.data = data or ""
end

local SIZE_UINT8 = 1
local SIZE_UINT16 = 2
local SIZE_UINT32 = 4
local SIZE_UINT64 = 8

local uint_func_info = {
	{ "uint8", SIZE_UINT8 },
	{ "uint16", SIZE_UINT16 },
	{ "uint32", SIZE_UINT32 },
	{ "uint64", SIZE_UINT64 },
}

function zwproto.readuint(size)
	argcheck( size <= #zwproto.data, "Not enough buffer(%d<=%d)", size, #zwproto.data )
	local r = string.unpack(string.format("<I%d", size), zwproto.data)
	zwproto.data = zwproto.data:sub(size+1)
	return r
end

function zwproto.writeuint(v, size)
	zwproto.data = zwproto.data .. string.pack(string.format("<I%d", size), tonumber(v))
end

for _, info in pairs(uint_func_info) do
	local fname = info[1]
	local size = info[2]
	zwproto["read" .. fname] = function()
		return zwproto.readuint(size)
	end
	zwproto["write" .. fname] = function(v)
		return zwproto.writeuint(v, size)
	end
end

local NUMBER_TYPE_0_BIT = 1 -- 0
local NUMBER_TYPE_1_BIT = 2 -- uint8
local NUMBER_TYPE_2_BIT = 3 -- uint16
local NUMBER_TYPE_4_BIT = 4 -- uint32
local NUMBER_TYPE_8_BIT = 5 -- uint64

local read_number_func = {
	[NUMBER_TYPE_0_BIT] = function()
		return 0
	end,
	[NUMBER_TYPE_1_BIT] = function()
		return zwproto.readuint8()
	end,
	[NUMBER_TYPE_2_BIT] = function()
		return zwproto.readuint16()
	end,
	[NUMBER_TYPE_4_BIT] = function()
		return zwproto.readuint32()
	end,
	[NUMBER_TYPE_8_BIT] = function()
		return zwproto.readuint64()
	end,
}

function zwproto.readnumber()
	local t = zwproto.readuint8()
	argcheck( read_number_func[t], "Invalid type(%d)", t )
	return read_number_func[t]()
end

function zwproto.writenumber(v)
	if v == 0 then
		return zwproto.writeuint8(NUMBER_TYPE_0_BIT)
	elseif v < 0x100 then
		zwproto.writeuint8(NUMBER_TYPE_1_BIT)
		zwproto.writeuint8(v)
	elseif v < 0x10000 then
		zwproto.writeuint8(NUMBER_TYPE_2_BIT)
		zwproto.writeuint16(v)
	elseif v < 0x100000000 then
		zwproto.writeuint8(NUMBER_TYPE_4_BIT)
		zwproto.writeuint32(v)
	else
		zwproto.writeuint8(NUMBER_TYPE_8_BIT)
		zwproto.writeuint64(v)
	end
end

function zwproto.readsize()
	local sv= zwproto.readuint8()
	if sv == 0xFF then
		return zwproto.readuint16()
	else
		return sv
	end
end

function zwproto.writesize(v)
	if v < 0xFF then
		zwproto.writeuint8(v)
	else
		zwproto.writeuint8(0xFF)
		zwproto.writeuint16(v)
	end
end

function zwproto.readstring()
	local length = zwproto.readsize()
	argcheck( #zwproto.data >= length, "Not enough buffer(%d>%d)", length, #zwproto.data )
	local r = zwproto.data:sub(1, length)
	zwproto.data:sub(length+1)
	return r
end

function zwproto.writestring(s)
	zwproto.writesize(#s)
	zwproto.data = zwproto.data .. s
end

function zwproto.writebytes(s)
	zwproto.data = zwproto.data .. s
end

return zwproto
