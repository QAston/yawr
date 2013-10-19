/++
+ This module provides access to all database data sources
+ Service locator pattern
+/
module authserver.database.dao;

import authserver.conf;
import authserver.database.db;

// import all dao classes here
public import authserver.database.realm;
public import authserver.database.auth;

/++
+ A database service locator class
+/
class Dao
{
    private RealmDao _realm;
    private AuthDao _auth;

    this(SqlDB database)
    {
        _realm = new RealmDao(database);
        _auth = new AuthDao(database);
    }

    RealmDao realm()
    {
        return _realm;
    }

    AuthDao auth()
    {
        return _auth;
    }
}

/++
+ Initialize Dao class singleton
+ Returns true on success
+/
void initDao()
{
    SqlDB database = createDatabase(getConfig());
    dao = new Dao(database);
}

private Dao dao;

Dao function() getDao = ()=>dao;