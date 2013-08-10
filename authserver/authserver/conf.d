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

shared static this()
{
    getOption("listenInterface", cast(string*)&listenInterface, "Ip address of the interface on which server will listen for connections");

    getOption("listenPort", cast(ushort*)&listenPort, "Port number which server will listen for connections");
        
    getOption("logFile", cast(string*)&logFile, "Path to log file");

    getOption("logFileLevel", cast(string*)&logFileLevel, "Level of messages to log to logFile");
}

/+
 + Returns true if program has valid settings and can continue execution
 +/
bool read()
{
    string[] args;
    return finalizeCommandLineOptions(&args);
}