#include <string.h>
#include <stdlib.h>
#include "msvcint.h"

#include "lua.h"
#include "lauxlib.h"

// msg, sz, complete_sz
static const void*
getbuffer(lua_State *L, int index, size_t *sz, size_t *complete_sz) {
	const void *buffer = NULL;
	int t = lua_type(L, index);
	if ( t!= LUA_TUSERDATA && t != LUA_TLIGHTUSERDATA ) {
		luaL_argerror(L, index, "Need a userdata");
		return NULL;
	}
	buffer = lua_touserdata(L, index);
	*sz = luaL_checkinteger(L, index+1);
	*complete_sz = luaL_checkinteger(L, index+2);
	luaL_argcheck(L, complete_sz < sz, 1, "complete_sz must be small than sz");
	return buffer;
}

#define READ_UINT(type) \
do \
{ \
	const void *buffer = NULL; \
	size_t sz = 0; \
	size_t complete_sz = 0; \
	type r = 0; \
	buffer = getbuffer(L, 1, &sz, &complete_sz); \
	luaL_argcheck(L, (sz - complete_sz) >= sizeof(r), 1, "Not enough buffer"); \
	memcpy(&r, buffer+complete_sz, sizeof(r)); \
	complete_sz += sizeof(r); \
	lua_pushinteger(L, r); \
	lua_pushinteger(L, complete_sz); \
	return 2; \
} \
while (0); \

/*
 * msg, sz, complete_sz -> number, complete_sz 
 */
static int
lreaduint8(lua_State *L) {
	READ_UINT(uint8_t);
}

static int
lreaduint16(lua_State *L) {
	READ_UINT(uint16_t);
}

static int
lreaduint32(lua_State *L) {
	READ_UINT(uint32_t);
}

static int
lreaduint64(lua_State *L) {
	READ_UINT(uint64_t);
}

#define NUMBER_TYPE_0_BIT 1 // 0
#define NUMBER_TYPE_1_BIT 2 // uint8
#define NUMBER_TYPE_2_BIT 3 // uint16
#define NUMBER_TYPE_4_BIT 4 // uint32
#define NUMBER_TYPE_8_BIT 5 // uint64

#define READ_NUMBER(size) \
do \
{ \
	luaL_argcheck(L, (sz - complete_sz) >= 1, 1, "Not enough buffer"); \
	uint8_t r = 0; \
	memcpy(&r, buffer+complete_sz, sizeof(r)); \
	complete_sz += sizeof(r); \
	lua_pushinteger(L, r); \
	lua_pushinteger(L, complete_sz); \
	return 2; \
}while(0); \

static int
lreadnumber(lua_State *L) {
	const void *buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	uint8_t type = 0;
	
	buffer = getbuffer(L, 1, &sz, &complete_sz);
	luaL_argcheck(L, (sz - complete_sz) >= 1, 1, "Not enough buffer");
	memcpy(&type, buffer+complete_sz, sizeof(type));
	complete_sz += sizeof(type);

	complete_sz += 1;
	switch( type ) {
		case NUMBER_TYPE_0_BIT:
		{
			lua_pushinteger(L, 0);
			lua_pushinteger(L, complete_sz);
			return 2;
		}
		break;

		case NUMBER_TYPE_1_BIT: // uint8_t
		{
			READ_NUMBER(sizeof(uint8_t));
		}
		break;

		case NUMBER_TYPE_2_BIT: // uint16_t
		{
			READ_NUMBER(sizeof(uint16_t));
		}
		break;

		case NUMBER_TYPE_4_BIT: // uint32_t
		{
			READ_NUMBER(sizeof(uint32_t));
		}
		break;

		case NUMBER_TYPE_8_BIT: // uint64_t
		{
			READ_NUMBER(sizeof(uint64_t));
		}
		break;

		default:
		{
			return luaL_error(L, "Invalid number type:%d", type);
		}
		break;
	}
}

static int
lreadstring(lua_State *L) {
	const void *buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	uint8_t slen = 0;
	uint16_t llen = 0;
	size_t len = 0;

	buffer = getbuffer(L, 1, &sz, &complete_sz);
	luaL_argcheck(L, (sz - complete_sz) >= sizeof(slen), 1, "Not enough buffer for short length");
	memcpy(&slen, buffer+complete_sz, sizeof(slen));
	complete_sz += sizeof(slen);
	len = slen;

	if ( slen == 0xFF ) {
		luaL_argcheck(L, (sz - complete_sz) >= sizeof(llen), 1, "Not enough buffer for long length");
		memcpy(&llen, buffer+complete_sz, sizeof(llen));
		complete_sz += sizeof(llen);
		len = llen;
	}
	
	luaL_argcheck(L, (sz - complete_sz) >= len, 1, "Not enough buffer");
	lua_pushlstring(L, (const char*)(buffer+complete_sz), len);
	complete_sz += len;
	lua_pushinteger(L, complete_sz);
	return 2;
}

int
luaopen_zwproto_core(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = {
		{ "readuint8", lreaduint8 },
		{ "readuint16", lreaduint16 },
		{ "readuint32", lreaduint32 },
		{ "readuint64", lreaduint64 },
		{ "readnumber", lreadnumber },
		{ "readstring", lreadstring },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);
	return 1;
}
