module protocol.opcode;

import protocol.version_;
import std.conv;

mixin ("public import protocol.opcode_." ~ protocolVersion.to!string() ~ ";");

string opcodeToString(Opcode opcode)
{
    string* ptr = (opcode in opcodeNames);
    if (ptr)
        return *ptr;
    return "<unknown opcode> " ~ (cast(ushort)opcode).to!string;
}

private string[Opcode] opcodeNames;

static this()
{
    foreach (member;__traits(allMembers, Opcode))
    {
        mixin("Opcode value = Opcode." ~ member ~ ";");
        opcodeNames[value] = member ~ " (" ~ (cast(ushort)value).to!string~")";
    }
}