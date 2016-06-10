local skynet = require "skynet"
local mysql = require "mysql"

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

local function test2( db)
    local i=1
    while true do
        local    res = db:query("select * from cats order by id asc")
        print ( "test2 loop times=" ,i,"\n","query result=",dump( res ) )
        res = db:query("select * from cats order by id asc")
        print ( "test2 loop times=" ,i,"\n","query result=",dump( res ) )

        skynet.sleep(1000)
        i=i+1
    end
end
local function test3( db)
    local i=1
    while true do
        local    res = db:query("select * from cats order by id asc")
        print ( "test3 loop times=" ,i,"\n","query result=",dump( res ) )
        res = db:query("select * from cats order by id asc")
        print ( "test3 loop times=" ,i,"\n","query result=",dump( res ) )
        skynet.sleep(1000)
        i=i+1
    end
end

local mysqldb = {}
mysql.db = nil

function mysqldb:connect( t )
	local function on_connect(db)
                db:query("set charset utf8");
        end
	
	t.on_connect = on_connect
	
        local ok, ret = xpcall(mysql.connect, debug.traceback, t)

	if not ok then
		return false, ret
	end

	if not ret then
		return false, "failed to connect mysql"
	end

	self.db = ret
	return true, ""
end

function mysqldb:executeSQL( sql )
	-- success
	-- ["server_status"] = 2,
        -- ["warning_count"] = 1,
        -- ["affected_rows"] = 0,
        -- ["insert_id"] = 0,
	
	-- error
	-- ["errno"] = 1051,
        -- ["badresult"] = true,
        -- ["sqlstate"] = "42S02",
        -- ["err"] = "Unknown table 'testsn.catsd'",

	if self.db == nil then
		return false, 0, "not connect db yet"
	end
	
	local ok, ret = xpcall(self.db.query, debug.traceback, self.db, sql)
	if not ok then
		return false, 0, ret
	end
	if ret.errno == nil then
		return true, 0, ""
	else
		return false, ret.errno, ret.err
	end
end

function mysqldb:query( sql )
	if self.db == nil then
		skynet.error("db is nil")
		return
	end

	-- ["errno"] = 1146,
        -- ["badresult"] = true,
        -- ["sqlstate"] = "42S02",
        -- ["err"] = "Table 'testsn.catsw' doesn't exist",

	local ok, ret = xpcall(self.db.query, debug.traceback, self.db, sql)
	if not ok then
		return false, 0, ret
	end
	if ret.errno == nil then
		return true, 0, "", ret
	else
		return false, ret.errno, ret.err, {}
	end
end

function mysqldb:close()
	if self.db ~= nil then
		self.db:disconnect()
	end
end

skynet.start(function()

	local ok, msg = mysqldb:connect({
		host="192.168.53.184",
		port=3306,
		database="testsn",
		user="root",
		password="eIhUX02LFAW9bnu9",
		max_packet_size = 1024 * 1024,
	})

	if not ok then
		skynet.error("failed to connect mysql", msg)
		skynet.exit()
		return
	end
	
	skynet.error("testmysql success to connect to mysql server")
	
	------------------------------------------------------------------
	-- drop table 
	local res, errno, err = mysqldb:executeSQL("drop table if exists cats")
	skynet.error( string.format("drop table operator result: %s, errno(%s) err(%s)", res, errno, err) )

	local res, errno, err = mysqldb:executeSQL("create table cats (id serial primary key, name varchar(5))")
	skynet.error( string.format("create table operator result: %s, errno(%s) err(%s)", res, errno, err) )

	local res, errno, err = mysqldb:executeSQL("insert into cats (name) values (\'Bob\'),(\'\'),(null)")
	skynet.error( string.format("insert table operator result: %s, errno(%s) err(%s)", res, errno, err) )

	local res, errno, err, result = mysqldb:query("select * from cats order by id asc")
	skynet.error( string.format("select table operator result: %s, errno(%s) err(%s)", res, errno, err) )
	if errno == 0 then
		for k, v in ipairs(result) do
			-- skynet.error( string.format("[%s] = %s", k, v) )
			for k1, v1 in pairs(v) do
				skynet.error( string.format("[%s] = %s", k1, v1) )
			end 
		end
	end

	local res, errno, err = mysqldb:query("insert into cats (name) values (\'Bob\'),(\'\'),(null)")
	skynet.error( string.format("insert table operator result: %s, errno(%s) err(%s)", res, errno, err) )

	local res, errno, err, result = mysqldb:query("select * from cats order by id asc")
	skynet.error( string.format("select table operator result: %s, errno(%s) err(%s)", res, errno, err) )
	if errno == 0 then
		for k, v in ipairs(result) do
			for k1, v1 in pairs(v) do
				skynet.error( string.format("[%s] = %s", k1, v1) )
			end
		end
	end

	-- bad sql statement
	local res, errno, err, result = mysqldb:query("select * from notexisttable" )
	skynet.error( string.format("bad select table operator result: %s, errno(%s) err(%s)", res, errno, err) )
        if errno == 0 then
                for k, v in ipairs(result) do
                        for k1, v1 in pairs(v) do
                                skynet.error( string.format("[%s] = %s", k1, v1) )
                        end
                end
        end

	mysqldb:close()
	skynet.exit()
end)

