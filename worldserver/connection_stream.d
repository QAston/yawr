module worldserver.connection_stream;

import wowprotocol.opcode;
import wowprotocol.packet_data;
import wowprotocol.session;

import util.stream;
import util.protocol.direction : Dir = Direction;

import vibe.d : TCPConnection;
import util.protocol.packet_stream;
import util.bit_memory_stream;
import util.struct_printer;

import util.crypto.hmac_digest;
import util.crypto.arc4;
import util.binary;

import std.conv;


/++
+ Deals with reading and writing data between client and server
+/
struct ConnectionStream
{
private:
    TCPConnection connectionStream;
    ARC4 inputDecrypt;
    ARC4 outputDecrypt;
    Session session;
public:
    this(TCPConnection connectionStream, ubyte[] K)
    {
        this.connectionStream = connectionStream;
        this.session = new Session();

        ubyte[] encryptHash = keyedDigest!HMAC(bin!r"CC98AE04E897EACA12DDC09342915357", K);
        ubyte[] decryptHash = keyedDigest!HMAC(bin!r"C2B3723CC6AED9B5343C53EE2F4367CE", K);

        inputDecrypt = ARC4(decryptHash);
        outputDecrypt = ARC4(encryptHash);

        // Drop first 1024 bytes, as WoW uses ARC4-drop1024.
        ubyte[1024] syncBuf;

        inputDecrypt.update(syncBuf);
        outputDecrypt.update(syncBuf);
    }

    /++
    + Reads next packet from stream. May block if needed
    +/
    Opcode read()
    {
        ubyte[] headerBytes = stream.sreadBytes(6);
        ubyte[] decodedHeader = inputDecrypt.update(headerBytes);

        ushort size = decodedHeader[0..2].read!(ushort, Endian.BigEndian);
        uint opcode = decodedHeader[2..6].read!(uint, Endian.LittleEndian);


        if ((size < 4) || (size > 10240))
        {
            throw new Exception();
        }

        size -= 4;

        return cast(Opcode)opcode;
    }

    /++
    + Reads specified packet data from TCP. May block if needed
    +/
    auto read(Opcode OPCODE)()
    {
        return .read!(OPCODE, Dir.c2s)(new PacketStream!true(new InputBitStreamWrapper(connectionStream), this.session.decompress));
    }

    /++
    + Writes specified packet to TCP
    +/
    void write(PACKET: PacketData!(PacketInfo!(OPCODE, Dir.s2c)), Opcode OPCODE)(PACKET* packet)
    in
    {
        assert(packet !is null);
    }
    body
    {
        logDiagnostic(logId ~ "Writing packet-opcode: %s", OPCODE.opcodeToString);

        logDebug(logId ~ "%s", fieldsToString(*packet));

        auto packetStream = new PacketStream!false(this.session.compress);
        .write(packet, connectionStream, packetStream);

        logDiagnostic(logId ~ "%s", packetStream.getData.toHex);
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

auto read(Opcode OPCODE, Dir DIR, STREAM)(STREAM packetStream)
{
    auto packet = Packet!(OPCODE, DIR, VER)();
    packetStream.val(packet);
    return packet;
}

void write(PACKET: PacketData!(PacketInfo!(OPCODE, DIR)), STREAM, PACKET_STREAM, Opcode OPCODE, Dir DIR)(PACKET* packet, STREAM stream, PACKET_STREAM packetStream)
in
{
    assert(packet !is null);
}
body
{
    packetStream.val(*packet);
    stream.swrite!ubyte(OPCODE);
    stream.write(packetStream.getData);
}