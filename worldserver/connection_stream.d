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
import util.bin;

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

        inputDecrypt.Init(decryptHash);
        outputDecrypt.Init(encryptHash);

        // Drop first 1024 bytes, as WoW uses ARC4-drop1024.
        ubyte[1024] syncBuf;

        inputDecrypt.update(1024, syncBuf);
        outputDecrypt.update(1024, syncBuf);
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

struct ClientPacketHeader
{
    Opcode opcode;
    uint size;
}


ClientPacketHeader readHeader(STREAM)(STREAM stream)
{
    ubyte[] headerBytes = stream.sreadBytes(4);

    m_Crypt.DecryptRecv ((uint8*)m_Header.rd_ptr(), sizeof(ClientPktHeader));

    ClientPktHeader& header = *((ClientPktHeader*)m_Header.rd_ptr());

    if ((header.size < 4) || (header.size > 10240) || (header.cmd > 10240))
    {
        ///error
    }

    header.size -= 4;

    ACE_NEW_RETURN(m_RecvWPct, WorldPacket ((uint16)header.cmd, header.size), -1);

    if (header.size > 0)
    {
        m_RecvWPct->resize(header.size);
        m_RecvPct.base ((char*) m_RecvWPct->contents(), m_RecvWPct->size());
    }
    else
    {
        assert(m_RecvPct.space() == 0);
    }
    
    return cast(Opcode)stream.sread!ubyte();
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