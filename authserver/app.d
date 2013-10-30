/++
+ Application entry point module.
+ Initializes the entire system.
+/
module authserver.app;

import std.conv;

import vibe.d : runEventLoop;
import util.log;

import authserver.session;
import authserver.conf;
import authserver.database.dao;
import authserver.log;

int main()
{
    int ret = 0;
    try
    {
        if (!initConfig())
            return 1;
        logInfo("authserver - Part of the Yet Another WowD Rewrite project");
        scope(exit)
            logInfo("authserver - shutting down");
        initLogging();
        initDao();
        initSessionListener();
        alias authserver.log logger;

        logger.logInfo("authserver started");

        ret = runEventLoop();
    }
    catch (Throwable t)
    {
        logError(t.to!string);
        return 1;
    }
    
    return ret;
}