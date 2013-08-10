module authserver.app;

import std.stdio;

import vibe.d : listenTCP, runEventLoop;

import util.stream;
import util.log;

import authserver.session;
static import authserver.conf;

shared static this()
{
    if (authserver.conf.listenInterface == "")
	    listenTCP(authserver.conf.listenPort, (conn){ (new Session(conn)).run(); });
    else
	    listenTCP(authserver.conf.listenPort, (conn){ (new Session(conn)).run(); }, authserver.conf.listenInterface);
}

int main()
{
    if (!authserver.conf.read)
        return 0;
    return runEventLoop();
}