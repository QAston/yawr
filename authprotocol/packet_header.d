module authprotocol.packet_header;

import authprotocol.defines;
import std.range;
import util.stream;

Opcode readClientHeader(INPUT)(INPUT range)
{
    return cast(Opcode)range.sread!ubyte();
}

void writeServerHeader(OUTPUT)(OUTPUT output, Opcode opcode)
{
    output.put(cast(ubyte)opcode);
}