/++
+ This module handles the state of current connection
+/
module authserver.session;

import std.conv;
import std.typecons;
import std.system;

import wowdefs.wow_versions;

import util.crypto.srp6;
import util.struct_printer;
import util.log;

import authprotocol.defines;
import authprotocol.packet_data;

import authserver.database.dao;
import authserver.connection_stream;
import authserver.packet_handler;
import authserver.conf;

import vibe.d : listenTCP, TCPConnection;

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

    ProtocolVersion protocolVersion;
    WowVersion clientBuild;

    ServerChallenge!(SRP!(Endian.littleEndian)) challenge;
    Nullable!(AuthDetailedDto) authInfo;

    this(ConnectionStream stream)
    {
        this.stream = stream;
    }

    static immutable SRP!(Endian.littleEndian) srp;

    shared static this()
    {
        import util.binary : bin;
        srp = cast(immutable)new SRP!(Endian.littleEndian)(bin!x"894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", [cast(ubyte)7], [cast(ubyte)3]);
    }

    void update()
    {
        .update(stream, protocolVersion, this);
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
        str.put(" protocol: " ~protocolVersion.to!string);
        str.put("): ");
        return str.data();
    }
}

void update(STREAM)(STREAM stream, ProtocolVersion protocolVersion, Session session)
{
    auto opcode = stream.read();
    auto fun = getHandler(opcode, protocolVersion);
    if (fun is null)
        throw new SessionException("Unexpected opcode: "~ opcode);

    fun(session);
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
private immutable void function(Session)[(Opcode.max + 1) * 2] packetHandlers;
shared static this()
{
    import std.traits;
    void setHandler(Opcode OPCODE, ProtocolVersion VER)()
    {
        packetHandlers[OPCODE*2 + VER] = &receivedPacket!(OPCODE, VER);
    }

    foreach(opcodeString;__traits(allMembers, Opcode))
    {
        foreach(ProtocolVersion ver; EnumMembers!ProtocolVersion)
        {
            mixin("setHandler!(Opcode."~ opcodeString~", ProtocolVersion."~ver.to!string~");");
        }
    }
}

package void function(Session) getHandler(Opcode opcode, ProtocolVersion protocolVersion)
{
    auto id = opcode*2 + protocolVersion;
    if (id >= packetHandlers.length)
        return null;
    return packetHandlers[opcode*2 + protocolVersion];
}

/++
+ Fallback handler for unimplemented packets
+/
void receivedPacket(Opcode OPCODE, ProtocolVersion VER)(Session session)
{
    throw new SessionException("Unexpected opcode: "~ OPCODE);
}

void receivedPacket(Opcode OPCODE : Opcode.AUTH_LOGON_CHALLENGE, ProtocolVersion VER)(Session session)
{
    auto packet = session.stream.read!(OPCODE, VER);
    assert(session.challenge is null);
    assert(session.authInfo.isNull);
    auto result = handleLogonChallenge(packet, session.srp, getDao().auth(), session.stream.getIp());
    session.stream.write(&result.packet);
    if (result.end)
    {
        session.end();
        return;
    }
    session.challenge = result.challenge;
    session.protocolVersion = result.version_;
    session.authInfo = result.authInfo;
}

void receivedPacket(Opcode OPCODE : Opcode.AUTH_LOGON_PROOF, ProtocolVersion VER)(Session session)
{
    auto packet = session.stream.read!(OPCODE, VER);

    auto response = handleLogonProof!VER(packet, session.challenge, session.authInfo);
    session.stream.write(&(response.packet));
    if (response.end)
        session.end();
}

/++
+ Sends client a list of active realms
+/
void receivedPacket(Opcode OPCODE : Opcode.REALM_LIST, ProtocolVersion VER)(Session session)
{
    auto packet = session.stream.read!(OPCODE, VER);

    auto ret = handleRealmList!VER(packet, getDao().realm());

    session.stream.write(&ret);
}

unittest {
}