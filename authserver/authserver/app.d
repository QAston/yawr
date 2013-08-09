module authserver.app;

import std.stdio;

import vibe.d : listenTCP, runEventLoop;

import util.stream;

import authserver.session;

immutable ushort bindPort = 3724;

shared static this()
{
    // Setup listening on a given port
	listenTCP(bindPort, (conn){ (new Session(conn)).run(); });
}

int main()
{
    return runEventLoop();
}