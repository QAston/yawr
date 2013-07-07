module protocol.packet;

import vibe.stream.memory;

import protocol.opcode;

class Packet 
{
    MemoryStream data;
    Opcode opcode;
    this(ubyte[] data, uint opcode)
    {
        this.data = new MemoryStream(data);
        this.opcode = cast(Opcode)opcode;
    }
}