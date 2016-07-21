#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include "msvcint.h"

#include "lua.h"
#include "lauxlib.h"

#define FIELD_READ_BUFFER 1
#define FIELD_READ_SZ 2
#define FIELD_READ_COMPLETE_SZ 3
#define FIELD_WRITE_BUFFER 4
#define FIELD_WRITE_SZ 5
#define FIELD_WRITE_COMPLETE_SZ 6
#define UPVALUE_TABLE 7

#define ENCODE_BUFFERSIZE 2050
#define ENCODE_MAXSIZE 0x1000000

#define debug printf
#define debug_assert assert

static const void*
getreadbuffer(lua_State *L, size_t *sz, size_t *complete_sz) {
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_BUFFER));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	void * buffer = lua_touserdata(L, 1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	*sz = lua_tointeger(L, 1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	*complete_sz = lua_tointeger(L, 1);
	lua_pop(L, 1);

	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer");
	luaL_argcheck(L, sz > 0, 1, "Invalid size of buffer");
	if ( !(sz >= complete_sz) ) {
		luaL_error(L, "Invalid complete size(%d>%d)", complete_sz, sz);
		return NULL;
	}
	return buffer;
}

static void*
getwritebuffer(lua_State *L, size_t *sz, size_t *complete_sz) {
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_BUFFER));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	void * buffer = lua_touserdata(L, -1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	*sz = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	*complete_sz = lua_tointeger(L, -1);
	lua_pop(L, 1);
	
	if ( !(sz >= complete_sz) ) {
		luaL_error(L, "Invalid complete size(%d>%d)", complete_sz, sz);
		return NULL;
	}
	return buffer;
}

/*
 * buffer, sz, complete_sz
 */
static int
lresetreadbuffer(lua_State *L) {
	void * buffer = lua_touserdata(L, 1);
	size_t sz = lua_tointeger(L, 2); 
	size_t complete_sz = luaL_checkinteger(L, 3);

	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer");
	luaL_argcheck(L, sz > 0, 2, "Invalid size of buffer");
	if ( !(sz >= complete_sz) ) {
		luaL_error(L, "Invalid complete size(%d>%d)", complete_sz, sz);
	}
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_BUFFER));
	lua_pushlightuserdata(L, buffer);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));
	
	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_SZ));
	lua_pushinteger(L, sz);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ));
	lua_pushinteger(L, complete_sz);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));
	return 0;
}

static int
lresetwritebuffer(lua_State *L) {
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ));
	lua_pushinteger(L, 0);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));
	return 0;
}

static void
updatecompletesz(lua_State *L, int index, size_t complete_sz) {
	debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );
	//debug("updatecompletesz|index(%d) complete_sz(%d)", index, complete_sz);

	lua_pushvalue(L, index);
	lua_pushinteger(L, complete_sz);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));
}

static void *
expandbuffer(lua_State *L, int osz, int nsz) {
	void *output;
	do {
		osz *= 2;
	} while (osz < nsz);
	if (osz > ENCODE_MAXSIZE) {
		luaL_error(L, "object is too large (>%d)", ENCODE_MAXSIZE);
		return NULL;
	}

	size_t oldsz;
	size_t oldcomplete_sz;
	void *oldoutput = getwritebuffer(L, &oldsz, &oldcomplete_sz);
	
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_BUFFER));
	output = lua_newuserdata(L, osz);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_SZ));
	lua_pushinteger(L, osz);
	lua_settable(L, lua_upvalueindex(UPVALUE_TABLE));

	memcpy(output, oldoutput, oldcomplete_sz);

	return output;
}

#define CHECK_COMPLETE_SZ(sz, complete_sz) \
do \
{ \
	if ( !(sz >= complete_sz) ) { \
		luaL_error(L, "Invalid complete size(%d>%d)", complete_sz, sz); \
		return 0; \
	} \
}while(0); \

#define READ_UINT(type) \
do \
{ \
	const void *buffer = NULL; \
	size_t sz = 0; \
	size_t complete_sz = 0; \
	type r = 0; \
	buffer = getreadbuffer(L, &sz, &complete_sz); \
	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer stream"); \
	CHECK_COMPLETE_SZ(sz, complete_sz); \
	if ( !((sz - complete_sz) >= sizeof(r)) ) { \
		luaL_error(L, "Not enough buffer(%d>%d)", sz - complete_sz, sizeof(r)); \
		return 0; \
	} \
	memcpy(&r, buffer+complete_sz, sizeof(r)); \
	complete_sz += sizeof(r); \
	updatecompletesz(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ), complete_sz); \
	lua_pushinteger(L, r); \
	return 1; \
} \
while (0); \

#define WRITE_UINT(type) \
do \
{ \
	void *buffer = NULL; \
	size_t sz = 0; \
	size_t complete_sz = 0; \
	type v = (type)luaL_checkinteger(L, 1); \
	buffer = getwritebuffer(L, &sz, &complete_sz); \
	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer stream"); \
	CHECK_COMPLETE_SZ(sz, complete_sz); \
	if ( (!(sz - complete_sz) > sizeof(v)) ) { \
		buffer = expandbuffer(L, sz, sz*2); \
		sz *= 2; \
		luaL_argcheck(L, buffer != NULL, 0, "Invalid buffer stream"); \
	} \
	memcpy(buffer+complete_sz, &v, sizeof(v)); \
	complete_sz += sizeof(v); \
	updatecompletesz(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ), complete_sz); \
	return 0; \
} while (0); \

#define EXPAND_BUFFER(nsz) \
do \
{ \
	if ( (sz - complete_sz) < nsz ) { \
		buffer = expandbuffer(L, sz, sz*2); \
		sz *= 2; \
		luaL_argcheck(L, buffer != NULL, 0, "Invalid buffer stream"); \
	} \
}while ( 0 ); \

/*
 * return number
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

static int
lreadsize(lua_State *L) {
	const void * buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	buffer = getreadbuffer(L, &sz, &complete_sz);
	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer steam");
	CHECK_COMPLETE_SZ(sz, complete_sz);

	uint16_t r = 0;

	uint8_t sv = 0;
	if ( !((sz - complete_sz) >= sizeof(sv)) ) {
		luaL_error(L, "Not enough buffer(%d>%d)", sz - complete_sz, sizeof(sv));
		return 0;
	}
	memcpy(&sv, buffer+complete_sz, sizeof(sv));
	complete_sz += sizeof(sv);
	r = sv;

	if ( sv == 0xFF ) {
		uint16_t lv = 0;
		if ( !((sz - complete_sz) >= sizeof(lv)) ) {
			luaL_error(L, "Not enough buffer(%d>%d)", sz - complete_sz, sizeof(lv));
			return 0;
		}
		memcpy(&lv, buffer+complete_sz, sizeof(lv));
		complete_sz += sizeof(lv);
		r = lv;
	}

	updatecompletesz(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ), complete_sz);
	lua_pushinteger(L, r);
	return 1;
}

static int
lwritesize(lua_State *L) {
	void *buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	buffer = getwritebuffer(L, &sz, &complete_sz);
	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer steam");
	CHECK_COMPLETE_SZ(sz, complete_sz);
	EXPAND_BUFFER(sizeof(uint8_t));
	uint64_t ov = luaL_checkinteger(L, 1);
	
	if ( ov >= 0xFF ) {
		uint8_t flag = 0xFF;
		memcpy(buffer+complete_sz, &flag, sizeof(flag));
		complete_sz += sizeof(flag);
	
		EXPAND_BUFFER(sizeof(uint16_t));
		uint16_t v = (uint16_t)ov;
		memcpy(buffer+complete_sz, &v, sizeof(v));
		complete_sz += sizeof(flag);
	}
	else {
		uint8_t v = (uint8_t)ov;
		memcpy(buffer+complete_sz, &v, sizeof(v));
		complete_sz += sizeof(v);
	}
	updatecompletesz(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ), complete_sz);
	return 0;
}

#define NUMBER_TYPE_0_BIT 1 // 0
#define NUMBER_TYPE_1_BIT 2 // uint8
#define NUMBER_TYPE_2_BIT 3 // uint16
#define NUMBER_TYPE_4_BIT 4 // uint32
#define NUMBER_TYPE_8_BIT 5 // uint64

#define READ_NUMBER(type) \
do \
{ \
	type r = 0; \
	CHECK_COMPLETE_SZ(sz, complete_sz); \
	if ( !((sz - complete_sz) >= sizeof(type)) ) { \
		luaL_error(L, "Not enough buffer(%d>%d)", sz - complete_sz, sizeof(r)); \
		return 0; \
	} \
	memcpy(&r, buffer+complete_sz, sizeof(type)); \
	complete_sz += sizeof(type); \
	updatecompletesz(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ), complete_sz); \
	lua_pushinteger(L, r); \
	return 1; \
}while(0); \

static int
lreadnumber(lua_State *L) {
	const void *buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	uint8_t type = 0;
	
	buffer = getreadbuffer(L, &sz, &complete_sz);
	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer stream");
	CHECK_COMPLETE_SZ(sz, complete_sz);
	if ( !((sz - complete_sz) >= sizeof(type)) ) {
		luaL_error(L, "Not enough buffer(%d>%d)", sz - complete_sz, sizeof(type));
		return 0;
	}
	memcpy(&type, buffer+complete_sz, sizeof(type));
	complete_sz += sizeof(type);

	switch( type ) {
		case NUMBER_TYPE_0_BIT: 
		{
			updatecompletesz(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ), complete_sz);
			lua_pushinteger(L, 0);
			return 1;
		}
		break;

		case NUMBER_TYPE_1_BIT: // uint8_t 
		{
			READ_NUMBER(uint8_t);
		}
		break;

		case NUMBER_TYPE_2_BIT: // uint16_t
		{
			READ_NUMBER(uint16_t);
		}
		break;

		case NUMBER_TYPE_4_BIT: // uint32_t
		{
			READ_NUMBER(uint32_t);
		}
		break;

		case NUMBER_TYPE_8_BIT: // uint64_t
		{
			READ_NUMBER(uint64_t);
		}
		break;

		default:
		{
			return luaL_error(L, "Invalid number type:%d", type);
		}
		break;
	}
}

/*
 * number
 */
static int
lwritenumber(lua_State *L) {
	void *buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	uint64_t v = luaL_checkinteger(L, 1);
	buffer = getwritebuffer(L, &sz, &complete_sz);
	luaL_argcheck(L, buffer != NULL, 1, "Invalid buffer steam");
	CHECK_COMPLETE_SZ(sz, complete_sz);

	// need a byte to write number type
	EXPAND_BUFFER(sizeof(uint8_t));

	if ( v == 0 ) {
		uint8_t type = NUMBER_TYPE_0_BIT;
		memcpy(buffer+complete_sz, &type, sizeof(type));
		complete_sz += sizeof(type);
	} 
	else if ( v < 0x100 ) {
		// write number type
		uint8_t type = NUMBER_TYPE_1_BIT;
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
	
	updatecompletesz(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ), complete_sz);
	return 0;
}

static int
lreadstring(lua_State *L) {
	const void *buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	uint8_t slen = 0;
	uint16_t llen = 0;
	size_t len = 0;

	buffer = getreadbuffer(L, &sz, &complete_sz);
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
	updatecompletesz(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ), complete_sz);
	return 1;
}

/*
 * string
 */
static int
lwritestring(lua_State *L) {
	void * buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	buffer = getwritebuffer(L, &sz, &complete_sz);
	
	size_t l = 0;
	const char *s = lua_tolstring(L, 1, &l);
	
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

	updatecompletesz(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ), complete_sz);
	return 0;
}

/*
 * return string
 */
static int
lgetwritebuffer(lua_State *L) {
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_BUFFER));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	void * buffer = lua_touserdata(L, -1);
	lua_pop(L, 1);
	
	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	size_t sz = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	size_t complete_sz = lua_tointeger(L, -1);
	lua_pop(L, 1);

	luaL_argcheck(L, sz >= complete_sz, 1, "Invalid complete_sz param");
	lua_pushlstring(L, buffer, complete_sz);
	return 1;
}

/*
 * return string
 */
static int
lgetreadbuffer(lua_State *L) {
	//debug_assert( lua_type(L, lua_upvalueindex(UPVALUE_TABLE)) == LUA_TTABLE );

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_BUFFER));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	const void * buffer = lua_touserdata(L, -1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	size_t sz = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_pushvalue(L, lua_upvalueindex(FIELD_READ_COMPLETE_SZ));
	lua_gettable(L, lua_upvalueindex(UPVALUE_TABLE));
	size_t complete_sz = lua_tointeger(L, -1);
	lua_pop(L, 1);

	luaL_argcheck(L, sz >= complete_sz, 1, "Invalid complete_sz param");

	lua_pushlstring(L, buffer, sz);
	lua_pushinteger(L, complete_sz);
	return 2;
}

/*
 * string, complete_sz --> complete_sz
 */
static int
lwritebytes(lua_State *L) {
	void * buffer = NULL;
	size_t sz = 0;
	size_t complete_sz = 0;
	buffer = getwritebuffer(L, &sz, &complete_sz);

	size_t l = 0;
	const char *s = lua_tolstring(L, 1, &l);

	EXPAND_BUFFER(l);
	memcpy(buffer+complete_sz, s, l);
	complete_sz += l;
	
	updatecompletesz(L, lua_upvalueindex(FIELD_WRITE_COMPLETE_SZ), complete_sz);
	return 0;
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
		{ "readsize", lreadsize },

		{ "writeuint8", lwriteuint8 },
		{ "writeuint16", lwriteuint16 },
		{ "writeuint32", lwriteuint32 },
		{ "writeuint64", lwriteuint64 },
		{ "writenumber", lwritenumber },
		{ "writestring", lwritestring },
		{ "writesize", lwritesize },

		{ "getreadbuffer", lgetreadbuffer },
		{ "getwritebuffer", lgetwritebuffer },
		{ "writebytes", lwritebytes },

		{ "resetreadbuffer", lresetreadbuffer },
		{ "resetwritebuffer", lresetwritebuffer },
				
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	// the order is the same with macros: FIELD_* (define top)
	lua_pushliteral(L, "read_buffer");
	lua_pushliteral(L, "read_sz");
	lua_pushliteral(L, "read_complete_sz");
	lua_pushliteral(L, "write_buffer");
	lua_pushliteral(L, "write_sz");
	lua_pushliteral(L, "write_complete_sz");
	
	lua_newtable(L);

	lua_pushliteral(L, "read_buffer");
	lua_pushlightuserdata(L, NULL);
	lua_settable(L, -3);

	lua_pushliteral(L, "read_sz");
	lua_pushinteger(L, 0);
	lua_settable(L, -3);

	lua_pushliteral(L, "read_complete_sz");
	lua_pushinteger(L, 0);
	lua_settable(L, -3);

	lua_pushliteral(L, "write_buffer");
	lua_newuserdata(L, ENCODE_BUFFERSIZE);
	lua_settable(L, -3);

	lua_pushliteral(L, "write_sz");
	lua_pushinteger(L, ENCODE_BUFFERSIZE);
	lua_settable(L, -3);

	lua_pushliteral(L, "write_complete_sz");
	lua_pushinteger(L, 0);
	lua_settable(L, -3);

	// sharing previous table as upvalue
	luaL_setfuncs(L, l, 7);
	return 1;
}
