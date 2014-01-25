/++
+ This module handles the state of current connection
+/
module worldserver.session;

import std.conv;
import std.system;
import std.typecons;

import wowdefs.wow_versions;

import util.crypto.srp6;
import util.struct_printer;
import util.log;

import wowprotocol.packet_data;
import wowprotocol.opcode;

import worldserver.database.dao;
import worldserver.connection_stream;
import worldserver.conf;

import vibe.d;


/++
+ Registers connection listener
+/
void initSessionListener()
{
    Config conf = getConfig();
    if (conf.listenInterface == "")
        listenTCP(conf.listenPort, (conn){ run(conn); });
    else
        listenTCP(conf.listenPort, (conn){ run(conn); }, conf.listenInterface);
}

/++
+ Starts and keep alive the client-server session
+/
void run(TCPConnection connectionStream)
{
    auto stream = ConnectionStream(connectionStream);
    logDiagnostic("Got connection:"~stream.logId());
    auto session = new Session(stream);
    scope(exit)
        logDiagnostic("Ended session" ~ session.logId());
    try {
        while(!session.isEnded())
        {
            session.update();
        }
    }
    catch(Throwable t)
    {
        logError(session.logId~"%s", t.to!string);
        session.end();
    }
}

/++
+ Session stores all state of a connection
+/
class Session
{
    ConnectionStream stream;

    this(ConnectionStream stream)
    {
        this.stream = stream;
    }

    void update()
    {
        auto opcode = stream.read();
        auto fun = getHandler(opcode);
        if (fun is null)
            throw new SessionException("Unexpected opcode: "~ opcode.opcodeToString());

        fun(this);
    }

    /// checks if connection to client is alive
    bool isEnded() const
    {
        return !stream.connected;
    }

    /// Ends the session - disconnects from client
    void end()
    {
        logDiagnostic(logId~"Ending session");
        if (stream.connected)
            stream.close();
    }

    /++
    + Returns string identifier for logging
    +/
    string logId() const
    {
        import std.array;
        auto str = appender!string();
        str.put("Session(");
        str.put(stream.logId());
        str.put("): ");
        return str.data();
    }
}

class SessionException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

/++
+ Data for dispatching opcode-protocolVersion pairs to function calls
+/
private immutable void function(Session)[(Opcode.max + 1)] packetHandlers;
shared static this()
{
    void setHandler(Opcode OPCODE)()
    {
        packetHandlers[OPCODE] = &receivedPacket!(OPCODE);
    }

    foreach(opcodeString;__traits(allMembers, Opcode))
    {
        mixin("setHandler!(Opcode."~ opcodeString~");");
    }
}

package void function(Session) getHandler(Opcode opcode)
{
    auto id = opcode;
    if (id >= packetHandlers.length)
        return null;
    return packetHandlers[opcode];
}

/++
+ Fallback handler for unimplemented packets
+/
void receivedPacket(Opcode OPCODE)(Session session)
{
    throw new SessionException("Unexpected opcode: "~ OPCODE.opcodeToString());
}

unittest {
}