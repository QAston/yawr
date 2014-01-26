/++
+ This module handles periodically applied db maineance queries
+/
module authserver.batch;

import authserver.conf;
import authserver.database.dao;
import authserver.log;

import core.time;
import vibe.core.core;

void run()
{
    Duration sleepDuration = dur!"seconds"(getConfig().batchProcessingInterval);
    auto auth = getDao().auth();

    while(true)
    {
        logDiagnostic("Applying batch queries to database...");
        auth.deleteExpiredIPBans();
        scope(exit)
            sleep(sleepDuration);
    }
}