module authserver.database.auth;

import authserver.database.db;
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