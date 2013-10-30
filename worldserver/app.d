/++
+ Application entry point module.
+ Initializes the entire system.
+/
module worldserver.app;

import std.conv;

import vibe.d : runEventLoop;
import util.log;

import worldserver.conf;
import worldserver.database.dao;
import worldserver.log;

int main()
{
    int ret = 0;
    try
    {
        if (!initConfig())
            return 1;
        logInfo("worldserver - Part of the Yet Another WowD Rewrite project");
        scope(exit)
            logInfo("worldserver - shutting down");
        initLogging();
        initDao();
        alias worldserver.log logger;

        logger.logInfo("worldserver started");

        ret = runEventLoop();
    }
    catch (Throwable t)
    {
        logError(t.to!string);
        return 1;
    }
    
    return ret;
}