module authserver.connection_stream;

import authprotocol.defines;
import authprotocol.packet_data;
import authprotocol.packet_header;

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
    Opcode nextOpcode;
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
        nextOpcode = connectionStream.readClientHeader();
        return nextOpcode;
    }

    /++
    + Reads specified packet data from TCP. May block if needed
    +/
    auto read(Opcode OPCODE, ProtocolVersion VER)()
    in
    {
        assert(OPCODE == nextOpcode);
    }
    body
    {
        auto packetStream = new PacketStream!true(new InputBitStreamWrapper(connectionStream), null);
        connectionStream.writeServerHeader(OPCODE);
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
        logDiagnostic(logId ~ "Writing packet-opcode: %s", OPCODE.to!string);

        logDebug(logId ~ "%s", fieldsToString(*packet));

        auto packetStream = new PacketStream!false(null);
        packetStream.val(*packet);
        connectionStream.writeServerHeader(OPCODE);
        connectionStream.write(packetStream.data);
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