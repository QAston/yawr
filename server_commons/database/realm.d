module server_commons.database.realm;

import util.mysql;

import authprotocol.defines;
import util.traits;

class RealmDao
{
    private SqlDB database;

    this(SqlDB database)
    {
        this.database = database;
    }

    auto getAll()
    {
        return database.selectResults!(RealmDto)(" FROM realmlist");
    }

    void removeRealmFlag(uint realmId, RealmFlags flag)
    {
        database.exec("UPDATE realmlist SET flag = (flag & ~?) WHERE id = ?", flag.toEnumBase(), realmId);
    }

    void addRealmFlag(uint realmId, RealmFlags flag)
    {
        database.exec("UPDATE realmlist SET flag = flag | ? WHERE id = ?", flag.toEnumBase(), realmId);
    }
}

struct RealmDto
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

