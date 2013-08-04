module p_parser.printer;

import std.traits;

import wowprotocol.packet_data;
import wowprotocol.opcode;

import util.struct_printer;

private static string function(void[])[Opcode] packetPrinters;

string print(Opcode opcode, void[] data)
in {
    assert (canStreamPacket(opcode));
}
body {
    return packetPrinters[opcode](data);
}

string packetPrinter(T)(void[] data)
{
    import std.stdio;
    assert(T.sizeof == data.length);
    return fieldsToString!(T)(*(cast(T*)data));
}

static this()
{
    foreach(opcodeString;__traits(allMembers, Opcode))
    {
        mixin("Opcode opcode = Opcode." ~ opcodeString ~ ";");
        if (cast(ushort)opcode == UNKNOWN_OPCODE)
            continue;

        mixin(q{
            static if(__traits(compiles, PacketData!(PacketInfo!(Opcode.}~ opcodeString ~q{))))
            {
                mixin("alias PacketData!(PacketInfo!(Opcode."~ opcodeString ~")) packetDataType;");

                packetPrinters[opcode] = &packetPrinter!(packetDataType);
            }});
    }
}