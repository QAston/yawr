/+
 + This module handles the state of current connection
 +/
module authserver.session;

import std.conv;
import std.stdio;

import wowdefs.wow_versions;

import util.bit_memory_stream;
import util.struct_printer;
import util.protocol.direction : Dir = Direction;
import util.protocol.packet_stream;

import authprotocol.packet_data;
import authprotocol.defines;
import authprotocol.opcode;

import vibe.d;

/+
 + Session class stores all state of a connection
 + Using class instead of thread local data because it's not fiber-local
 +/
class Session
{
    TCPConnection connectionStream;
    ProtocolVersion protocolVersion;

    immutable static void function()[(Opcode.max + 1) * 2] packetHandlers;

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
        try {
            while(!connectionStream.connected)
            {
                Opcode opc = cast(Opcode)connectionStream.sread!ubyte();
                receivedPacket(opc);
            }
        }
        catch(Throwable t)
        {
            writeln(t.to!string);
            end();
        }
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

        auto packetStream = new PacketStream!false(null);
        packetStream.val(*packet);
        connectionStream.swrite!ubyte(OPCODE);
        connectionStream.write(packetStream.getData);
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
        writefln("Received opcode: %s", OPCODE.to!string);
        auto packet = readPacket!(OPCODE, VER);
        writeln(packet.fieldsToString());

        protocolVersion = packet.build.major >= MajorWowVersion.TBC ? ProtocolVersion.POST_BC : ProtocolVersion.PRE_BC;
        auto response = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Dir.s2c, VER)();
        response.result = AuthResult.WOW_FAIL_BANNED;
        writePacket(&response);
        end();
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
        writefln("Uhnandled opcode: %s", op.to!string);
        end();
    }

    /// Ends the session - disconnects from client
    void end()
    {
        if (!connectionStream.connected)
            connectionStream.close();
    }
}