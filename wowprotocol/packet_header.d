module wowprotocol.packet_header;
import util.binary;

ClientHeader readClientHeader(INPUT)(INPUT range)
{
    ubyte[] sizeBytes = range[0..2];
    ubyte[] opcodeBytes = range[2..6];

    ushort size = std.bitmanip.read!(ushort, Endian.bigEndian)(sizeBytes);
    uint opcode = std.bitmanip.read!(uint, Endian.littleEndian)(opcodeBytes);

    if ((size < 4) || (size > 10240))
    {
        throw new Exception("");
    }
    return ClientHeader(size-4, cast(ushort)opcode);
}

struct ClientHeader
{
    private uint _dataSize;
    private ushort _opcode;

    @property ushort opcode() const
    {
        return _opcode;
    }
    @property uint dataSize() const
    {
        return _dataSize;
    }
    @property uint size() const
    {
        return dataSize + 4;
    }
}

void writeServerHeader(OUTPUT)(OUTPUT range, const(ServerHeader) header)
{
    if (header.size > 0x7FFF)
    {
        range.put(cast(ubyte)(0x80 | (0xFF & (header.size >> 16))));
    }
    range.put(cast(ubyte)(0xFF & (header.size >> 8)));
    range.put(cast(ubyte)(0xFF & header.size));

    range.put(cast(ubyte)(0xFF & header.opcode));
    range.put(cast(ubyte)(0xFF & (header.opcode >> 8)));
}

struct ServerHeader
{
    private uint _dataSize;
    private ushort _opcode;
    @property ushort opcode() const
    {
        return _opcode;
    }
    @property uint dataSize() const
    {
        return _dataSize;
    }
    @property uint size() const
    {
        return dataSize + 2;
    }
}
