module worldserver.connection_stream;

import wowprotocol.opcode;
import wowprotocol.packet_data;
import wowprotocol.session;
import wowprotocol.packet_header;

import util.stream;
import util.protocol.direction : Dir = Direction;

import vibe.d : TCPConnection;
import vibe.stream.memory;
import util.protocol.packet_stream;
import util.bit_memory_stream;
import util.struct_printer;

import util.crypto.hmac_digest;
import util.crypto.arc4;
import util.binary;
import util.crypto.big_num;
import worldserver.log;

import std.conv;
import std.array;

/++
+ Deals with reading and writing data between client and server
+/
struct ConnectionStream
{
private:
    TCPConnection connectionStream;
    Cipher inputCipher;
    Cipher outputCipher;
    Session session;
    ClientHeader nextHeader;
public:
    this(TCPConnection connectionStream)
    {
        this.connectionStream = connectionStream;
        this.session = new Session();

        inputCipher = new NullCipher;
        outputCipher = new NullCipher;
    }

    void initCipher(ubyte[] K)
    {
        ubyte[] encryptHash = keyedDigest!HMAC(bin!r"CC98AE04E897EACA12DDC09342915357", K);
        ubyte[] decryptHash = keyedDigest!HMAC(bin!r"C2B3723CC6AED9B5343C53EE2F4367CE", K);

        inputCipher = new ARC4Cipher(decryptHash);
        outputCipher = new ARC4Cipher(encryptHash);

        // Drop first 1024 bytes, as WoW uses ARC4-drop1024.
        ubyte[1024] syncBuf;

        inputCipher.update(syncBuf);
        outputCipher.update(syncBuf);
    }

    /++
    + Reads next packet from stream. May block if needed
    +/
    Opcode read()
    {
        ubyte[] cipheredHeaderBytes = connectionStream.sreadBytes(6);
        ubyte[] headerBytes = inputCipher.update(cipheredHeaderBytes);
        nextHeader = readClientHeader(headerBytes);
        logDiagnostic("Got header: %s", (cast(Opcode)nextHeader.opcode).opcodeToString);
        logDiagnostic("Got data size: %s", nextHeader.dataSize);
        return cast(Opcode)nextHeader.opcode;
    }

    /++
    + Reads specified packet data from TCP. May block if needed
    +/
    auto read(Opcode OPCODE)()
    {
        assert(OPCODE == nextHeader.opcode);

        auto readBuffer = new ubyte[nextHeader.dataSize];
        connectionStream.read(readBuffer);
        auto inputStream = new PacketStream!true(readBuffer, &this.session.decompress);
        auto packet = Packet!(OPCODE, Dir.c2s)();
        inputStream.val(packet);
        return packet;
    }

    /++
    + Writes specified packet to TCP
    +/
    void write(PACKET: PacketData!(PacketInfo!(OPCODE, Dir.s2c)), Opcode OPCODE)(ref PACKET packet)
    {
        logDiagnostic(logId ~ "Writing packet-opcode: %s", OPCODE.opcodeToString);

        logDebug(logId ~ "%s", fieldsToString(packet));

        auto packetStream = new PacketStream!false(&this.session.compress);
        packetStream.val(packet);
        auto ciphered = appender!(ubyte[]);
        ciphered.writeServerHeader(ServerHeader(packetStream.data.length, OPCODE));
        ubyte[] cipheredHeader = outputCipher.update(ciphered.data);

        auto stream  = new MemoryOutputBitStream();
        stream.write(cipheredHeader);
        stream.write(packetStream.data);
        connectionStream.write(stream.data);

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