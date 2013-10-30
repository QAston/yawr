module worldserver.log;

public import util.log;

import worldserver.conf;
import std.conv;

void initLogging()
{
    Config config = getConfig();
    // setup file logging if desired
    if (config.logFile != "")
    {
        util.log.setLogFile(config.logFile, config.logFileLevel.to!LogLevel);
        util.log.logDiagnostic("log set for file %s", config.logFile);
    }
}