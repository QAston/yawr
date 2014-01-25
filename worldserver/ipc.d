/++
+ This module is responsible for interprocess communication bettween server processes
+/
module worldserver.ipc;

import worldserver.database.dao;
import worldserver.conf;
import authprotocol.defines;

void registerStartup()
{
    getDao().realm.removeRealmFlag(getConfig().realmId, RealmFlags.REALM_FLAG_OFFLINE);
}

void registerShutdown()
{
    getDao().realm.addRealmFlag(getConfig().realmId, RealmFlags.REALM_FLAG_OFFLINE);
}