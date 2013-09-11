/++
+ Handles db connection of authserver
+ TODO: use other db provider than vibe.d - can't pool prepared statements with current implementation]
+ TODO: fix ultra leaky interface
+/
module authserver.db;

import mysql.db;
static import authserver.conf;
import util.log;

private static MysqlDB db;

void init()
{
    assert(db is null);
    db = new MysqlDB(authserver.conf.authDbConnectionString);
}

auto getDbCmd()
{
    return new Command(db.lockConnection());
}



struct AuthInfo
{
    long id;
    string username;
    string sha_pass_hash;
    string sessionkey;
    string v;
    string s;
}

struct RealmInfo
{
    string name;
    string address;
    ushort port;
    ubyte icon;
    ubyte flag;
    ubyte timezone;
    ubyte allowedSecurityLevel;
    float population;
    uint gamebuild;
}

import std.range;

private RESULT_TYPE toStructRet(RESULT_TYPE)(Row row)
{
    RESULT_TYPE res;
    row.toStruct(res);
    return res;
}

/++
+ Adapter which wraps a range of Rows into a range of RESULT_TYPE
+/
struct ResultRange(RESULT_TYPE, RANGE) if (isInputRange!(RANGE) && is (typeof(RANGE.front) == Row))
{
private:
    RANGE range;
public:
    static if (isInputRange!(RANGE))
    {
        @property RESULT_TYPE front()
        {
            return range.front.toStructRet!(RESULT_TYPE);
        }

        void popFront()
        {
            range.popFront();
        }

        @property bool empty() { return range.empty(); }
    }

    static if (isForwardRange!(RANGE))
    {
        @property typeof(this) save()
        {
            return this;
        }
    }

    static if (isBidirectionalRange!(RANGE))
    {
        @property RESULT_TYPE back()
        {
            return range.back.toStructRet!(RESULT_TYPE);
        }

        void popBack()
        {
            range.popBack();
        }
    }

    static if (isRandomAccessRange!(RANGE))
    {
        RESULT_TYPE opIndex(size_t i)
        {
            return range[i].toStructRet!(RESULT_TYPE);
        }

        @property size_t length() { return range.length; }
    }
}

unittest {
    struct A{
    }
    static assert(isInputRange!(ResultRange!(A, ResultSet)));
    static assert(isBidirectionalRange!(ResultRange!(A, ResultSequence)));
}

/++
+ Given a range of SQL Rows and a RESULT_TYPE returns a range of RESULT_TYPEs to which rows are converted
+ Useful for typesafe SQL data access
+/
auto resultRange(RESULT_TYPE, RANGE)(RANGE range)
{
    return ResultRange!(RESULT_TYPE, RANGE)(range);
}

unittest {
    struct A{
    }
    resultRange!(A)(ResultSet.init);
}

/++
+ Returns a comma separated list of all fields from a struct of given type T
+/
string formatSqlColumnList(T)() pure
{
    // make sure it's only a simple struct
    static assert(__traits(allMembers, T).length == T.tupleof.length);
    import std.array;
    auto app = appender!(string);
    bool first = true;
    foreach (a; __traits(allMembers, T))
    {
        if (first)
        {
            first = false;
        }
        else
        {
            app.put(", ");
        }
        app.put(a);
    }
    return app.data();
}


unittest {

    struct Test {
        uint a;
        ushort b;
    }
    
    assert(formatSqlColumnList!(Test) == "a, b");
}