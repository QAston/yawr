module server_commons.database.auth;

import util.mysql;
import std.conv;
import std.datetime;

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

    auto getDetailed(const(char)[] accountName)
    {
        return database.result!(AuthDetailedDto)("SELECT a.username, a.sha_pass_hash, a.id, a.locked, a.lock_country, a.last_ip, aa.gmlevel, a.v, a.s FROM account a LEFT JOIN account_access aa ON (a.id = aa.id) WHERE a.username = ?", accountName);
    }

    void deleteExpiredIPBans()
    {
        database.exec("DELETE FROM ip_banned WHERE unbandate<>bandate AND unbandate<=UNIX_TIMESTAMP()");
    }

    void updateExpiredAccountBans()
    {
        database.exec("UPDATE account_banned SET active = 0 WHERE active = 1 AND unbandate<>bandate AND unbandate<=UNIX_TIMESTAMP()");
    }

    auto getIpBanned(const(char)[] ip)
    {
        return database.selectResult!(IpBannedDto)("FROM ip_banned WHERE ip = ?", ip);
    }

    auto getAccountBanned(long id)
    {
        return database.selectResult!(AccountBannedDto)("SELECT bandate, unbandate FROM account_banned WHERE id = ? AND active = 1", id);
    }

    auto getCountry(const(char)[] ip)
    {
        return database.result!(string)("SELECT country FROM ip2nation WHERE ip < ? ORDER BY ip DESC LIMIT 0,1", ip);
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

struct AuthDetailedDto
{
    string username;
    string sha_pass_hash;
    long id;
    bool locked;
    string country;
    string lastIp;
    uint gmLevel;
    string v;
    string s;
}

struct IpBannedDto
{
    string ip;
    uint bandate;
    uint unbanbate;
    string bannedby;
    string banreason;
}

struct AccountBannedDto
{
    long id;
    uint bandate;
    uint unbanbate;
    string bannedby;
    string banreason;
}

bool suspended(ref AccountBannedDto dto)
{
    return dto.bandate != dto.unbanbate;
}