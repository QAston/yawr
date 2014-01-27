/++
+ Module with utils and wrappers for mysql db access
+/
module util.mysql;

import mysql.db;
import mysql.connection;
import util.db;
import std.typecons;
import std.algorithm;

final class SqlCommand
{
    this(SqlDB db)
    {
        cmd = new Command(db.db.lockConnection());
    }

    mixin Proxy!cmd;
private:
    Command* cmd;
}

final class SqlDB
{
    /++
    + Creates sql database connection based on connection string
    +/
    this(string connectionString)
    {
        this.db = new MysqlDB(connectionString);
    }

    /++
    + Retuns sql command object for communications to database
    +/
    SqlCommand createCommand()
    {
        return new SqlCommand(this);
    }

    /++
    + executes an sql statement with given params
    +/
    bool exec(PARAMS...)(string statement, PARAMS params)
    {
        auto cmd = createCommand();
        cmd.sql = statement;
        cmd.prepare();
        static if (PARAMS.length > 0)
            cmd.cmd.bindParameterTuple!(PARAMS)(params);
        ulong rows;
        return cmd.execPrepared(rows);
    }

    /++
    + Returns a range of results of a SELECT query to database
    + Params:
    +   RESULT_TYPE - SELECTed structure
    + Args:
    +   query - full query - SELECT, FROM, WHERE and other sql clauses of a query
    +   params - prepared statement params for query
    +/
    auto results(RESULT_TYPE, PARAMS...)(string query, PARAMS params)
    {
        auto cmd = createCommand();
        cmd.sql = query;
        cmd.prepare();
        static if (PARAMS.length > 0)
            cmd.cmd.bindParameterTuple!(PARAMS)(params);
        return cmd.execPreparedResult().resultRange!(RESULT_TYPE)();
    }

    /++
    + Returns a Nullable!RESULT_TYPE result of a SELECT query to database
    + Params:
    +   RESULT_TYPE - SELECTed structure
    + Args:
    +   query - full query - SELECT, FROM, WHERE and other sql clauses of a query
    +   params - prepared statement params for query
    +/
    auto result(RESULT_TYPE, PARAMS...)(string query, PARAMS params)
    {
        auto res = results!(RESULT_TYPE)(query, params);
        assert(res.length < 2);
        if (res.length == 0)
            return Nullable!(RESULT_TYPE)();
        return Nullable!(RESULT_TYPE)(res.front);
    }

    /++
    + Returns a range of results of a SELECT query to database, produces query string based on structure field names
    + Selects fields names exactly like structure fields.
    + Params:
    +   RESULT_TYPE - SELECTed structure - field names and types must match db
    + Args:
    +   fromWhere - query without SELECT [...], only FROM, WHERE and other clauses
    +   params - prepared statement params for fromWhere clause
    +/
    auto selectResults(RESULT_TYPE, PARAMS...)(string fromWhere, PARAMS params)
    {
        return results!(RESULT_TYPE)("SELECT " ~ formatSqlColumnList!(RESULT_TYPE)() ~ fromWhere, params);
    }

    /++
    + Returns a Nullable!RESULT_TYPE result of a SELECT query to database
    + Params:
    +   RESULT_TYPE - SELECTed structure - field names and types must match db
    + Args:
    +   fromWhere - FROM, WHERE and other sql clauses of a query
    +   params - prepared statement params for fromWhere clause
    +/
    auto selectResult(RESULT_TYPE, PARAMS...)(string fromWhere, PARAMS params)
    {
        auto res = selectResults!(RESULT_TYPE)(fromWhere, params);
        assert(res.length < 2);
        if (res.length == 0)
            return Nullable!(RESULT_TYPE)();
        return Nullable!(RESULT_TYPE)(res.front);
    }
private:
    MysqlDB db;
}

/++
+ Given a range of SQL Rows and a RESULT_TYPE returns a range of RESULT_TYPEs to which rows are converted
+ Useful for typesafe SQL data access
+/
auto resultRange(RESULT_TYPE, RANGE)(RANGE range)
{
    return range.map!(toStructRet!(RESULT_TYPE));
}

public auto toStructRet(RESULT_TYPE)(Row row) if (!is(RESULT_TYPE == class))
{
    static if (!is (RESULT_TYPE == struct))
    {
        Tuple!(RESULT_TYPE) res;

        row.toStruct(res);
        return res[0];
    }
    else 
    {
        RESULT_TYPE res;
    
        row.toStruct(res);
        return res;
    }
}