/++
+ Handles db connection of authserver
+ TODO: use other db provider than vibe.d - can't pool prepared statements with current implementation]
+/
module authserver.db;

static import authserver.conf;
public import util.mysql;

public static SqlDB db;
static this()
{
    db = new SqlDB(authserver.conf.authDbConnectionString);
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
