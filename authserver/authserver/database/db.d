/++
+ Handles db connection of authserver
+/
module authserver.database.db;

import authserver.conf;
public import util.mysql;

SqlDB createDatabase(Config conf)
{
    return new SqlDB(conf.authDbConnectionString);
}