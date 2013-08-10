/+
 + Module responsible for fetching authserver-specific config options from cmd line and vibe.conf file
 +/
module authserver.conf;

import util.conf;

immutable string listenInterface;
immutable ushort listenPort;
immutable string logFile;
immutable string logFileLevel;

shared static this()
{
    if (!getOption("listenInterface", cast(string*)&listenInterface, "Ip address of the interface on which server will listen for connections"))
        listenInterface = "";

    if (!getOption("listenPort", cast(ushort*)&listenPort, "Port number which server will listen for connections"))
        listenPort = 3724;

    if (!getOption("logFile", cast(string*)&logFile, "Path to log file"))
        logFile = "";

    if (!getOption("logFileLevel", cast(string*)&logFile, "Level of messages to log to logFile"))
        logFile = "";
}

/+
 + Returns true if program has valid settings and can continue execution
 +/
bool read()
{
    string[] args;
    return !finalizeCommandLineOptions(&args);
}