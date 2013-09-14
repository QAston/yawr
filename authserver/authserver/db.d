/++
+ Handles db connection of authserver
+ TODO: use other db provider than vibe.d - can't pool prepared statements with current implementation]
+ TODO: fix ultra leaky interface
+/
module authserver.db;

import mysql.db;
static import authserver.conf;
import util.log;
public import util.db;
import std.algorithm;

private static MysqlDB db;

import std.typecons;

void init()
{
    assert(db is null);
    db = new MysqlDB(authserver.conf.authDbConnectionString);
}

auto getDbCmd()
{
    return new Command(db.lockConnection());
}

/++
+ Given a range of SQL Rows and a RESULT_TYPE returns a range of RESULT_TYPEs to which rows are converted
+ Useful for typesafe SQL data access
+/
auto resultRange(RESULT_TYPE, RANGE)(RANGE range)
{
    return range.map!(toStructRet!(RESULT_TYPE));
}

public RESULT_TYPE toStructRet(RESULT_TYPE)(Row row)
{
    RESULT_TYPE res;
    row.toStruct(res);
    return res;
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
