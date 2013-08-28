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