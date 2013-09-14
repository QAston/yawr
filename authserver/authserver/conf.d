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
immutable bool canStart;

shared static this()
{
    loadOpt("listenInterface", listenInterface, "Ip address of the interface on which server will listen for connections");

    loadOpt("listenPort", listenPort, "Port number which server will listen for connections");
        
    loadOpt("logFile", logFile, "Path to log file");

    loadOpt("logFileLevel", logFileLevel, "Level of messages to log to logFile");

    loadOpt("authDbConnectionString", authDbConnectionString, "Mysql connection string in format: host=localhost;user=user;pwd=password;db=auth");

    string[] args;
    canStart = finalizeCommandLineOptions(&args);
}