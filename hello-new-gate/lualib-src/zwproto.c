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

#define ENCODE_BUFFERSIZE 2050
#define ENCODE_MAXSIZE 0x1000000

static void *
expand_buffer(lua_State *L, int osz, int nsz) {
	void *output;
	do {
		osz *= 2;
	} while (osz < nsz);
	if (osz > ENCODE_MAXSIZE) {
		luaL_error(L, "object is too large (>%d)", ENCODE_MAXSIZE);
		return NULL;
	}
	output = lua_newuserdata(L, osz);
	lua_replace(L, lua_upvalueindex(1));
	lua_pushinteger(L, osz);
	lua_replace(L, lua_upvalueindex(2));

	return output;
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

#define WRITE_UINT(type) \
do \
{ \
	void * buffer = lua_touserdata(L, lua_upvalueindex(1)); \
	int sz = lua_tointeger(L, lua_upvalueindex(2)); \
	type v = (type)luaL_checkinteger(L, 1); \
	size_t complete_sz = luaL_checkinteger(L, 2); \
	luaL_argcheck(L, sz >= complete_sz, 2, "Invalid complete_sz param"); \
	if ( (sz - complete_sz) < sizeof(v) ) { \
		buffer = expand_buffer(L, sz, sz*2); \
		sz *= 2; \
		luaL_argcheck(L, buffer != NULL, 0, "Invalid buffer stream"); \
	} \
	memcpy(buffer+complete_sz, &v, sizeof(v)); \
	complete_sz += sizeof(v); \
	lua_pushinteger(L, complete_sz); \
	return 1; \
} \
while (0);

/*
 * msg, sz, complete_sz -> number, complete_sz 
 */
static int
lreaduint8(lua_State *L) {
	READ_UINT(uint8_t);
}

/*
 * number, complete_sz -> complete_sz
 */
static int
lwriteuint8(lua_State *L) {
	WRITE_UINT(uint8_t);
}

static int
lreaduint16(lua_State *L) {
	READ_UINT(uint16_t);
}

static int
lwriteuint16(lua_State *L) {
	WRITE_UINT(uint16_t);
}

static int
lreaduint32(lua_State *L) {
	READ_UINT(uint32_t);
}

static int
lwriteuint32(lua_State *L) {
	WRITE_UINT(uint32_t);
}

static int
lreaduint64(lua_State *L) {
	READ_UINT(uint64_t);
}

static int
lwriteuint64(lua_State *L) {
	WRITE_UINT(uint64_t);
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

#define EXPAND_BUFFER(nsz) \
do \
{ \
	if ( (sz - complete_sz) < nsz ) { \
		buffer = expand_buffer(L, sz, sz*2); \
		sz *= 2; \
		luaL_argcheck(L, buffer != NULL, 0, "Invalid buffer stream"); \
	} \
}while ( 0 ); \


/*
 * number, complete_sz -> complete_sz
 */
static int
lwritenumber(lua_State *L) {
	void * buffer = lua_touserdata(L, lua_upvalueindex(1));
	int sz = lua_tointeger(L, lua_upvalueindex(2));
	uint64_t v = luaL_checkinteger(L, 1);
	size_t complete_sz = luaL_checkinteger(L, 2);
	luaL_argcheck(L, sz >= complete_sz, 2, "Invalid complete_sz param");

	// need a byte to write number type
	EXPAND_BUFFER(sizeof(uint8_t));

	if ( v == 0 ) {
		uint8_t type = NUMBER_TYPE_0_BIT;
		memcpy(buffer+complete_sz, &type, sizeof(type));
		complete_sz += sizeof(type);
	} 
	else if ( v < 0x100 ) {
		// write number type
		uint8_t type = NUMBER_TYPE_0_BIT;
		memcpy(buffer+complete_sz, &type, sizeof(type));
		complete_sz += sizeof(type);

		// write number value
		EXPAND_BUFFER(sizeof(uint8_t));
		uint8_t r = (uint8_t)v;
		memcpy(buffer+complete_sz, &r, sizeof(r));
		complete_sz += sizeof(r);
	}
	else if ( v < 0x10000 ) {
		// write number type
		uint8_t type = NUMBER_TYPE_2_BIT;
		memcpy(buffer+complete_sz, &type, sizeof(type));
		complete_sz += sizeof(type);

		// write number value
		EXPAND_BUFFER(sizeof(uint16_t));
		uint16_t r = (uint16_t)v;
		memcpy(buffer+complete_sz, &r, sizeof(r));
		complete_sz += sizeof(r);
	}
	else if ( v < 0x100000000 ) {
		// write number type
		uint8_t type = NUMBER_TYPE_4_BIT;
		memcpy(buffer+complete_sz, &type, sizeof(type));
		complete_sz += sizeof(type);

		// write number value
		EXPAND_BUFFER(sizeof(uint32_t));
		uint32_t r = (uint32_t)v;
		memcpy(buffer+complete_sz, &r, sizeof(r));
		complete_sz += sizeof(r);
	}
	else {
		// write number type
		uint8_t type = NUMBER_TYPE_8_BIT;
		memcpy(buffer+complete_sz, &type, sizeof(type));
		complete_sz += sizeof(type);

		// write number value
		EXPAND_BUFFER(sizeof(uint64_t));
		uint64_t r = (uint64_t)v;
		memcpy(buffer+complete_sz, &r, sizeof(r));
		complete_sz += sizeof(r);
	}
	
	lua_pushinteger(L, complete_sz);
	return 1;
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

/*
 * string, complete_sz -> complete_sz
 */
static int
lwritestring(lua_State *L) {
	void * buffer = lua_touserdata(L, lua_upvalueindex(1));
	int sz = lua_tointeger(L, lua_upvalueindex(2));
	size_t l = 0;
	const char *s = lua_tolstring(L, 1, &l);
	size_t complete_sz = luaL_checkinteger(L, 2);
	luaL_argcheck(L, sz >= complete_sz, 2, "Invalid complete_sz param");

	if ( l >= 0xFF ) {
		uint8_t ssz = 0xFF;
		uint16_t lsz = l;
		EXPAND_BUFFER(sizeof(ssz) + sizeof(lsz));
		memcpy(buffer+complete_sz, &ssz, sizeof(ssz));
		complete_sz += sizeof(ssz);
		memcpy(buffer+complete_sz, &lsz, sizeof(lsz));
		complete_sz += sizeof(lsz);
		EXPAND_BUFFER(lsz);
		memcpy(buffer+complete_sz, s, lsz);
		complete_sz += lsz;
	}
	else {
		uint8_t ssz = l;
		EXPAND_BUFFER(sizeof(ssz));
		memcpy(buffer+complete_sz, &ssz, sizeof(ssz));
		complete_sz += sizeof(ssz);
		EXPAND_BUFFER(ssz);
		memcpy(buffer+complete_sz, s, ssz);
		complete_sz += ssz;
	}

	lua_pushinteger(L, complete_sz);
	return 1;
}

/*
 * complete_sz --> string
 */
static int
lgetbuffer(lua_State *L) {
	void * buffer = lua_touserdata(L, lua_upvalueindex(1));
	int sz = lua_tointeger(L, lua_upvalueindex(2));
	size_t complete_sz = luaL_checkinteger(L, 1);
	luaL_argcheck(L, sz >= complete_sz, 1, "Invalid complete_sz param");

	lua_pushlstring(L, buffer, complete_sz);
	return 1;
}

/*
 * string, complete_sz --> complete_sz
 */
static int
lwritebytes(lua_State *L) {
	void * buffer = lua_touserdata(L, lua_upvalueindex(1));
	int sz = lua_tointeger(L, lua_upvalueindex(2));
	size_t l = 0;
	const char *s = lua_tolstring(L, 1, &l);
	size_t complete_sz = luaL_checkinteger(L, 2);
	luaL_argcheck(L, sz >= complete_sz, 1, "Invalid compelte_sz param");

	EXPAND_BUFFER(l);
	memcpy(buffer+complete_sz, s, l);
	complete_sz += l;
	
	lua_pushinteger(L, complete_sz);
	return 1;
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

		{ "writeuint8", lwriteuint8},
		{ "writeuint16", lwriteuint16},
		{ "writeuint32", lwriteuint32},
		{ "writeuint64", lwriteuint64},
		{ "writenumber", lwritenumber},
		{ "writestring", lwritestring},
		{ "getbuffer", lgetbuffer},
		{ "writebytes", lwritebytes},
				
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	lua_newuserdata(L, ENCODE_BUFFERSIZE);
	lua_pushinteger(L, ENCODE_BUFFERSIZE);
	luaL_setfuncs(L, l, 2);

	return 1;
}
