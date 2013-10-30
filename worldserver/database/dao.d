/++
+ This module provides access to all database data sources
+ Service locator pattern
+/
module worldserver.database.dao;

import worldserver.conf;
import util.mysql;

// import all dao classes here
public import server_commons.database.realm;
public import server_commons.database.auth;

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
+/
void initDao()
{
    SqlDB database = new SqlDB(getConfig().authDbConnectionString);
    dao = new Dao(database);
}

private Dao dao;

Dao function() getDao = ()=>dao;