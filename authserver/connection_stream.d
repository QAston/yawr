module authserver.connection_stream;

import authprotocol.defines;
import authprotocol.packet_data;

import util.stream;
import util.protocol.direction : Dir = Direction;

import vibe.d;
import util.protocol.packet_stream;
import util.bit_memory_stream;
import util.struct_printer;

/++
+ Deals with reading and writing data between client and server
+/
struct ConnectionStream
{
private:
    TCPConnection connectionStream;
public:
    this(TCPConnection connectionStream)
    {
        this.connectionStream = connectionStream;
    }

    /++
    + Reads next packet from stream. May block if needed
    +/
    Opcode read()
    {
       return .readHeader(this.connectionStream);
    }

    /++
    + Reads specified packet data from TCP. May block if needed
    +/
    auto read(Opcode OPCODE, ProtocolVersion VER)()
    {
        return .read!(OPCODE, VER, Dir.c2s)(new PacketStream!true(new InputBitStreamWrapper(connectionStream), null));
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
        logDiagnostic(logId ~ "Writing packet-opcode: %s", OPCODE.to!string);

        logDebug(logId ~ "%s", fieldsToString(*packet));

        auto packetStream = new PacketStream!false(null);
        .write(packet, connectionStream, packetStream);

        logDiagnostic(logId ~ "%s", packetStream.data.toHex);
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
}

Opcode readHeader(STREAM)(STREAM stream)
{
    return cast(Opcode)stream.sread!ubyte();
}

auto read(Opcode OPCODE, ProtocolVersion VER, Dir DIR, STREAM)(STREAM packetStream)
{
    auto packet = Packet!(OPCODE, DIR, VER)();
    packetStream.val(packet);
    return packet;
}

void write(PACKET: PacketData!(PacketInfo!(OPCODE, DIR, VER)), STREAM, PACKET_STREAM, Opcode OPCODE, ProtocolVersion VER, Dir DIR)(PACKET* packet, STREAM stream, PACKET_STREAM packetStream)
in
{
    assert(packet !is null);
}
body
{
    packetStream.val(*packet);
    stream.swrite!ubyte(OPCODE);
    stream.write(packetStream.data);
}

unittest
{
    import util.typecons : emptyArray;
    auto packet = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Dir.s2c, ProtocolVersion.PRE_BC)();
    packet.result = AuthResult.WOW_SUCCESS;
    auto secInf = typeof(packet).SecurityInfo();
    secInf.flags = SecurityFlags.TOKEN_INPUT;
    secInf.token = typeof(secInf).Token(cast(ubyte)1);
    secInf.g = emptyArray!ubyte;
    secInf.N = emptyArray!ubyte;
    packet.info = secInf;
    auto buffer = new ubyte[200];
    auto outstream = new MemoryStream(buffer);
    auto ps = new PacketStream!false(null);
    write(&packet, outstream, ps);
    auto instream = new InputBitStreamWrapper(new MemoryStream(buffer));
    assert(readHeader(instream) == Opcode.AUTH_LOGON_CHALLENGE);
    auto newPacket = read!(Opcode.AUTH_LOGON_CHALLENGE, ProtocolVersion.PRE_BC, Dir.s2c)(new PacketStream!true(instream, null));
    assert(newPacket == packet);
}