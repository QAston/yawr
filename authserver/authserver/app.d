module authserver.app;

import std.conv;

import vibe.d : listenTCP, runEventLoop;
import util.log;

import authserver.session;
static import authserver.conf;
import authserver.db;


shared static this()
{
    if (authserver.conf.listenInterface == "")
	    listenTCP(authserver.conf.listenPort, (conn){ (new Session(conn)).run(); });
    else
	    listenTCP(authserver.conf.listenPort, (conn){ (new Session(conn)).run(); }, authserver.conf.listenInterface);
}

int main()
{
    logInfo("authserver - Part of the Yet Another WowD Rewrite project");
    if (!authserver.conf.read)
        return 0;

    int ret = 0;
    try
    {
        // setup file logging if desired
        if (authserver.conf.logFile != "")
        {
            setLogFile(authserver.conf.logFile, authserver.conf.logFileLevel.to!LogLevel);
            logDiagnostic("log set for file %s", authserver.conf.logFile);
        }

        authserver.db.init();

        logInfo("authserver started");
        ret = runEventLoop();
    }
    catch (Throwable t)
    {
        logError(t.to!string);
        return 1;
    }
    logInfo("authserver - shutting down");
    return ret;
}