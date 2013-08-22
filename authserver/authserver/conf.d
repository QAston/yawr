/+
 + Module responsible for fetching authserver-specific config options from cmd line and vibe.conf file
 +/
module authserver.conf;

import util.conf;
import util.log;

immutable string listenInterface;
immutable ushort listenPort = 3724;
immutable string logFile;
immutable uint logFileLevel;
immutable string authDbConnectionString;

private shared void loadOpt(T)(string optName, immutable ref T loadTo, string description)
{
    getOption(optName, cast(T*)&loadTo, description);
}

shared static this()
{
    loadOpt("listenInterface", listenInterface, "Ip address of the interface on which server will listen for connections");

    loadOpt("listenPort", listenPort, "Port number which server will listen for connections");
        
    loadOpt("logFile", logFile, "Path to log file");

    loadOpt("logFileLevel", logFileLevel, "Level of messages to log to logFile");

}

/+
 + Returns true if program has valid settings and can continue execution
 +/
bool read()
{
    string[] args;
    return finalizeCommandLineOptions(&args);
}