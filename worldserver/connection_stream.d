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


void doHandshakes(TCPConnection connectionStream, uint seed)
{
    {
        auto packet = Packet!(Opcode.SMSG_AUTH_CHALLENGE, Dir.s2c)();
        packet.shuffleCount = 1; // 1...31
        packet.serverSeed = seed;

        auto number = random(4*8*8);
        packet.newSeeds = cast(uint[])number.toByteArray(Endian.bigEndian); // new encryption seed

        auto packetStream = new PacketStream!false(null);
        packetStream.val(packet);
        auto stream  = new MemoryOutputBitStream();
        stream.writeServerHeader(ServerHeader(packetStream.data.length, Opcode.SMSG_AUTH_CHALLENGE));

        stream.write(packetStream.data);

        connectionStream.write(stream.data());
    }

    {
        ubyte[] headerBytes = connectionStream.sreadBytes(6);
        ClientHeader header = readClientHeader(headerBytes);

        logDiagnostic("Got packet: %s", (cast(Opcode)header.opcode).opcodeToString);

        auto readBuffer = new ubyte[header.dataSize];
        connectionStream.read(readBuffer);
        auto inputStream = new PacketStream!true(readBuffer, null);
        auto packet = Packet!(Opcode.CMSG_AUTH_SESSION, Dir.c2s)();
        inputStream.val(packet);
    }
}


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
        ubyte[] encodedHeaderBytes = connectionStream.sreadBytes(6);
        ubyte[] decodedHeader = inputDecrypt.update(encodedHeaderBytes);
        ClientHeader header = readClientHeader(decodedHeader);

        return cast(Opcode)header.opcode;
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