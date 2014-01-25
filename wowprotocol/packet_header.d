module wowprotocol.packet_header;

immutable struct ServerHeader
{
    uint size;
    uint opcode;
};

/+
/**
* size is the length of the payload _plus_ the length of the opcode
*/
this(uint size, uint cmd) pure
{
    this.size = size;
    uint8 headerIndex=0;
    if (isLargePacket())
    {
        header[headerIndex++] = 0x80 | (0xFF & (size >> 16));
    }
    header[headerIndex++] = 0xFF & (size >> 8);
    header[headerIndex++] = 0xFF & size;

    header[headerIndex++] = 0xFF & cmd;
    header[headerIndex++] = 0xFF & (cmd >> 8);
}

ubyte getHeaderLength() const
{
    // cmd = 2 bytes, size= 2||3bytes
    return 2 + (isLargePacket() ? 3 : 2);
}

bool isLargePacket() const
{
    return size > 0x7FFF;
}+/


immutable struct ClientHeader
{
    ushort size;
    uint cmd;
};