/++
+ This module handles the state of current connection
+/
module authserver.session;

import std.conv;
import std.system;
import std.typecons;

import wowdefs.wow_versions;

import util.stream;
import util.bit_memory_stream;
import util.struct_printer;
import util.protocol.direction : Dir = Direction;
import util.protocol.packet_stream;
import util.log;
import util.state_trans;

import util.crypto.srp6;

import authprotocol.packet_data;
import authprotocol.defines;

import authserver.db;

import vibe.d;

/++
+ Registers connection listener
+/
shared static this()
{
    if (authserver.conf.listenInterface == "")
	    listenTCP(authserver.conf.listenPort, (conn){ run(conn); });
    else
	    listenTCP(authserver.conf.listenPort, (conn){ run(conn); }, authserver.conf.listenInterface);
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
+ Deals with reading and writing data between client and server
+/
struct ConnectionStream
{
    this(TCPConnection connectionStream)
    {
        this.connectionStream = connectionStream;
    }

    /++
    + Reads next packet from stream. May block if needed
    +/
    Opcode read()
    {
        return cast(Opcode)connectionStream.sread!ubyte();
    }

    /++
    + Reads specified packet data from TCP. May block if needed
    +/
    auto read(Opcode OPCODE, ProtocolVersion VER)()
    {
        auto packetStream = new PacketStream!true(new InputBitStreamWrapper(connectionStream), null);
        auto packet = Packet!(OPCODE, Dir.c2s, VER)();
        packetStream.val(packet);
        return packet;
    }

    /++
    + Writes specified packet to TCP
    +/
    void write(PACKET: PacketData!(PacketInfo!(OPCODE, Dir.s2c, VER)), Opcode OPCODE, ProtocolVersion VER)(PACKET* packet)
    in
    {
        assert(packet !is null);
    }
    body
    {
        import util.stream;
        import util.struct_printer;

        logDiagnostic(logId ~ "Sent packet-opcode: %s", OPCODE.to!string);
        auto packetStream = new PacketStream!false(null);
        packetStream.val(*packet);
        connectionStream.swrite!ubyte(OPCODE);
        logDiagnostic(logId ~ "%s", packetStream.getData.toHex);
        connectionStream.write(packetStream.getData);
        logDebug(fieldsToString(*packet));
    }

    /// returns true if connection is still active
    bool connected() const
    {
        return connectionStream.connected();
    }

    /// closes the connection
    void close()
    {
        connectionStream.close();
    }

    string logId() const
    {
        return "ConnectionStream: "~connectionStream.peerAddress.to!string;
    }
private:
    TCPConnection connectionStream;
}

/++
+ Session stores all state of a connection
+/
final class Session
{
    ConnectionStream stream;

    ProtocolVersion protocolVersion;
    WowVersion clientBuild;

    ServerChallenge!(typeof(srp)) challenge;
    Nullable!AuthInfo authInfo;

    this(ConnectionStream stream)
    {
        this.stream = stream;
    }

    static SRP!(Endian.littleEndian) srp;

    static this()
    {
        import util.binary : bin;
        srp = new SRP!(Endian.littleEndian)(bin!x"894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", [cast(ubyte)7], [cast(ubyte)3]);
    }

    void update()
    {
        auto opcode = stream.read();
        auto fun = getHandler(opcode, protocolVersion);
        if (fun is null)
            throw new SessionException("Unexpected opcode: "~ opcode);

        fun(this);
    }

    /// checks if connection to client is alive
    bool isEnded() const
    {
        return stream.connected;
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

private void function(Session) getHandler(Opcode opcode, ProtocolVersion protocolVersion)
{
    auto id = opcode*2 + protocolVersion;
    if (id >= packetHandlers.length)
        return null;
    return packetHandlers[opcode*2 + protocolVersion];
}

class SessionException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
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
    import std.algorithm;
    import util.crypto.big_num;
    import std.system;

    auto packet = session.stream.read!(OPCODE, VER);
    
    session.protocolVersion = packet.build.major >= MajorWowVersion.TBC ? ProtocolVersion.POST_BC : ProtocolVersion.PRE_BC;

    auto response = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Dir.s2c, VER)();

    session.authInfo = db.selectResult!(AuthInfo)(" FROM account WHERE username=?", packet.accountName);
    if (session.authInfo.isNull())
    {
        response.result = AuthResult.WOW_FAIL_UNKNOWN_ACCOUNT;
        session.stream.write(&response);
        session.end();
        return;
    }

    assert(session.challenge is null);

    session.challenge = new ServerChallenge!(typeof(session.srp))(util.crypto.big_num.random(19*8).toByteArray(Endian.littleEndian)[],session.srp);

    response.result = AuthResult.WOW_SUCCESS;
    auto secInf = typeof(response).SecurityInfo();
    auto bbytes = session.challenge.calculateB(BigNumber(session.authInfo.v).toByteArray(Endian.littleEndian));
    bbytes.length = 32;
    secInf.B []= bbytes[];
    secInf.g = session.srp.gbytes();
    secInf.N = session.srp.Nbytes();
    secInf.s []= BigNumber(session.authInfo.s).toByteArray(Endian.littleEndian)[];
    secInf.unkRand []= util.crypto.big_num.random(16*8).toByteArray(Endian.littleEndian)[];

    response.info = secInf;

    session.stream.write(&response);
}

void receivedPacket(Opcode OPCODE : Opcode.AUTH_LOGON_PROOF, ProtocolVersion VER)(Session session)
{
    import util.crypto.big_num;
    import std.system;
    auto packet = session.stream.read!(OPCODE, VER);
    auto response = Packet!(Opcode.AUTH_LOGON_PROOF, Dir.s2c, VER)();

    auto proof = session.challenge.challenge(cast(ubyte[])session.authInfo.username, BigNumber(session.authInfo.s).toByteArray(Endian.littleEndian), BigNumber(session.authInfo.v).toByteArray(Endian.littleEndian), packet.A);

    auto authResult = proof.authenticate(packet.M1);
    if (authResult is null)
    {
        response.error = AuthResult.WOW_FAIL_UNKNOWN_ACCOUNT;
        response.unkAccError = typeof(response).UnknownAccError();
        session.stream.write(&response);
        session.end();
        return;
    }

    response.error = AuthResult.WOW_SUCCESS;
    auto respProof = typeof(response).Proof();
    respProof.M2 []= (*authResult).M2[];
    static if (VER == ProtocolVersion.POST_BC)
    {
        respProof.flags = AccountFlags.PRO_PASS;
    }
    response.proof = respProof;

    session.stream.write(&response);
}

/++
+ Sends client a list of active realms
+/
void receivedPacket(Opcode OPCODE : Opcode.REALM_LIST, ProtocolVersion VER)(Session session)
{
    import util.typecons;
    import std.algorithm;
    auto packet = session.stream.read!(OPCODE, VER);
    auto response = Packet!(Opcode.REALM_LIST, Dir.s2c, VER)();
    auto result = db.selectResults!(authserver.db.RealmInfo)(" FROM realmlist");
    response.realms = new authprotocol.packet_data.RealmInfo!(VER)[result.length];
    size_t i = 0;
    foreach (realm ; result)
    {   
        auto realmData = authprotocol.packet_data.RealmInfo!(VER)(cast(RealmFlags)realm.flag, realm.name.to!(char[]), (realm.address.to!string ~ ":" ~realm.port.to!string).to!(char[]), realm.population, 0, realm.timezone, realm.icon);
        static if (VER == ProtocolVersion.POST_BC)
        {
            auto pi = getPatchInfo(cast(WowVersion)realm.gamebuild);
            realmData.build = BuildInfo(pi.major, pi.minor, pi.bugfix, cast(WowVersion)realm.gamebuild);
            realmData.unk = 0x2C;
        }
        else
            realmData.unk = 0x0;
        response.realms[i++] = realmData;
    }

    if (VER == ProtocolVersion.POST_BC)
    {
        response.unk1 = 0x10;
        response.unk2 = 0x0;
    }
    else
    {
        response.unk1 = 0x0;
        response.unk2 = 0x2;
    }
    session.stream.write(&response);
}