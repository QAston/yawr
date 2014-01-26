module server_commons.database.auth;

import util.mysql;
import std.conv;

class AuthDao
{
    this(SqlDB database)
    {
        this.database = database;
    }

    private SqlDB database;

    auto get(const(char)[] accountName)
    {
        return database.selectResult!(AuthDto)(" FROM account WHERE username=?", accountName.to!(char[]));
    }

    void deleteExpiredIPBans()
    {
        database.exec("DELETE FROM ip_banned WHERE unbandate<>bandate AND unbandate<=UNIX_TIMESTAMP()");
    }
}

struct AuthDto
{
    long id;
    string username;
    string sha_pass_hash;
    string sessionkey;
    string v;
    string s;
}