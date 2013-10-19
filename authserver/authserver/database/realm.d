module authserver.database.realm;

import authserver.database.db;

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

