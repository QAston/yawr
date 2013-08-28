/+
 + This module handles the state of current connection
 +/
module authserver.session;

import std.conv;

import wowdefs.wow_versions;

import util.bit_memory_stream;
import util.struct_printer;
import util.protocol.direction : Dir = Direction;
import util.protocol.packet_stream;
import util.log;

import util.crypto.srp6;

import authprotocol.packet_data;
import authprotocol.defines;
import authprotocol.opcode;

import authserver.db;

import vibe.d;

/+
 + Session class stores all state of a connection
 + Using class instead of thread local data because it's not fiber-local
 +/
final class Session
{
    TCPConnection connectionStream;
    ProtocolVersion protocolVersion;

    immutable static void function()[(Opcode.max + 1) * 2] packetHandlers;
    static SRP srp;

    shared static this()
    {
        import std.traits;
        void setHandler(Opcode OPCODE, ProtocolVersion VER)()
        {
            packetHandlers[OPCODE*2 + VER] = &Session.receivedPacket!(OPCODE, VER);
        }

        foreach(opcodeString;__traits(allMembers, Opcode))
        {
            foreach(ProtocolVersion ver; EnumMembers!ProtocolVersion)
            {
                mixin("setHandler!(Opcode."~ opcodeString~", ProtocolVersion."~ver.to!string~");");
            }
        }
        import util.crypto.big_num;
        srp = new SRP(cast(ubyte[])x"894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", [cast(ubyte)7]);
    }


    this(TCPConnection connectionStream)
    {
        this.connectionStream = connectionStream;
    }

    /+
     + Main loop of the session
     + We just keep fetching data
     +/
    void run()
    {
        import util.stream;
        logDiagnostic(logId~"Starting session");
        try {
            while(connectionStream.connected)
            {
                Opcode opc = cast(Opcode)connectionStream.sread!ubyte();
                receivedPacket(opc);
            }
        }
        catch(Throwable t)
        {
            logError(logId~"%s", t.to!string);
            end();
        }
        logDiagnostic(logId~"Ended session");
    }

    /+
     + Reads specified packet data from TCP
     +/
    auto readPacket(Opcode OPCODE, ProtocolVersion VER)()
    {
        auto packetStream = new PacketStream!true(new InputBitStreamWrapper(connectionStream), null);
        auto packet = Packet!(OPCODE, Dir.c2s, VER)();
        packetStream.val(packet);
        return packet;
    }

    /+
     + Writes specified packet data to TCP
     +/
    void writePacket(PACKET: PacketData!(PacketInfo!(OPCODE, Dir.s2c, VER)), Opcode OPCODE, ProtocolVersion VER)(PACKET* packet)
    in
    {
        assert(packet !is null);
    }
    body
    {
        import util.stream;
        import util.struct_printer;

        logDiagnostic(logId~"Sent packet-opcode: %s", OPCODE.to!string);
        auto packetStream = new PacketStream!false(null);
        packetStream.val(*packet);
        connectionStream.swrite!ubyte(OPCODE);
        connectionStream.write(packetStream.getData);
        logDebug(logId~fieldsToString(*packet));
    }

    // A dispatcher for received packets
    void receivedPacket(Opcode opcode)
    {
        auto id = opcode*2 + protocolVersion;
        if (id > packetHandlers.length)
        {
            unexpectedOpcode(opcode);
            return;
        }
        auto fun = packetHandlers[opcode*2 + protocolVersion];
        if (fun is null)
        {
            unexpectedOpcode(opcode);
            return;
        }

        void delegate() call;
        call.ptr = cast(void*)this;
        call.funcptr = packetHandlers[opcode*2 + protocolVersion];
        call();
    }

    void receivedPacket(Opcode OPCODE : Opcode.AUTH_LOGON_CHALLENGE, ProtocolVersion VER)()
    {
        import util.crypto.big_num;
        import std.system;
        logDiagnostic(logId~"Received opcode: %s", OPCODE.to!string);
        auto packet = readPacket!(OPCODE, VER);
        logDebug(logId~"Received opcode: %s \n", packet.fieldsToString());

        protocolVersion = packet.build.major >= MajorWowVersion.TBC ? ProtocolVersion.POST_BC : ProtocolVersion.PRE_BC;
        auto response = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Dir.s2c, VER)();

        auto cmd = getDbCmd();
        cmd.sql = "SELECT id, username, sha_pass_hash, sessionkey, v, s FROM account WHERE username=?";
        cmd.prepare();
        cmd.bindParameterTuple(packet.accountName);
        logDiagnostic(logId~"auth_logon 2");
        auto result = cmd.execPreparedResult();
        if (result.empty())
        {
            response.result = AuthResult.WOW_FAIL_UNKNOWN_ACCOUNT;
            writePacket(&response);
            end();
            return;
        }

        assert(result.length == 1);
        auto authInfo = AuthInfo();
        result.front.toStruct(authInfo);
        auto challenge = new ServerChallenge(cast(ubyte[])x"E487CB59 D31AC550 471E81F0 0F6928E0 1DDA08E9 74A004F4 9E61F5D1 05284D20",srp);
        //auto proof = challenge.challenge(authInfo.username, authInfo.s, authInfo.v, result.A);
        response.result = AuthResult.WOW_SUCCESS;
        auto secInf = typeof(response).SecurityInfo();
        auto bbytes = challenge.calculateB(BigNumber(authInfo.v).toByteArray(Endian.bigEndian));
        bbytes.length = 32;
        secInf.B []= bbytes[];
        secInf.g = srp.gbytes();
        secInf.N = srp.Nbytes();
        secInf.s []= BigNumber(authInfo.s).toByteArray(Endian.bigEndian)[];
        secInf.unkRand []= util.crypto.big_num.random(16*8).toByteArray(Endian.bigEndian)[];

        response.info = secInf;
        
        writePacket(&response);
    }
    
    /+
     + Fallback handler for unimplemented packets
     +/
    void receivedPacket(Opcode OPCODE, ProtocolVersion VER)()
    {
        unexpectedOpcode(OPCODE);
    }

    /// 
    void unexpectedOpcode(Opcode op)
    {
        logError(logId~"Received unexpected opcode: %s", op.to!string);
        end();
    }

    /// Ends the session - disconnects from client
    void end()
    {
        logDiagnostic(logId~"Ending session", );
        if (connectionStream.connected)
            connectionStream.close();
    }

    /+
     + Returns string identifier for logging
     +/
    string logId()
    {
        import std.array;
        auto str = appender!string();
        str.put("Session(");
        str.put("peerIP: " ~connectionStream.peerAddress.to!string);
        str.put(" protocol: " ~protocolVersion.to!string);
        str.put("): ");
        return str.data();
    }
}