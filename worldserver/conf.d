/++
+ Module responsible for fetching worldserver-specific config options from cmd line and vibe.conf file
+/
module worldserver.conf;

import util.conf;

/++
+ Returns newly created config object
+ must be called once on the beginning of program
+/
auto createConfig()
{
    auto c = new Config;
    loadOpt("listenInterface", c.listenInterface, "Ip address of the interface on which server will listen for connections");

    loadOpt("listenPort", c.listenPort, "Port number which server will listen for connections");

    loadOpt("logFile", c.logFile, "Path to log file");

    loadOpt("logFileLevel", c.logFileLevel, "Level of messages to log to logFile");

    loadOpt("authDbConnectionString", c.authDbConnectionString, "Mysql connection string in format: host=localhost;user=user;pwd=password;db=auth");

    string[] args;
    if (finalizeCommandLineOptions(&args))
        return c;
    return null;
}

immutable class Config
{
    immutable string listenInterface;
    immutable ushort listenPort;
    immutable string logFile;
    immutable uint logFileLevel;
    immutable string authDbConnectionString;
    pure this()
    {
        listenPort = 3724;
        listenInterface = "";
        logFile = "";
        logFileLevel = 0;
        authDbConnectionString = "";
    }
}

private __gshared Config config;

Config function() getConfig = ()=>config;

bool initConfig()
{
    config = createConfig();
    return config !is null;
}