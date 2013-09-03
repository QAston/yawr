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

/++
+ Returns a comma separated list of all fields from a struct of given type T
+/
string formatSqlColumnList(T)()
{
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