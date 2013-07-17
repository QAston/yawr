/+
 + Handles access to wowVersion dependent Opcode enum
 +/
module protocol.opcode;

import wowdefs.wow_version;
import std.conv;

enum UNKNOWN_OPCODE = 0x0000;
mixin ("public import protocol.opcode_." ~ wowVersion.to!string() ~ ";");

/+
 + Converts given opcode to a string
 +/
string opcodeToString(Opcode opcode)
{
    string* ptr = (opcode in opcodeNames);
    if (ptr)
        return *ptr;
    return "<unknown opcode> " ~ (cast(ushort)opcode).to!string;
}

private static string[Opcode] opcodeNames;

static this()
{
    foreach (member;__traits(allMembers, Opcode))
    {
        mixin("Opcode value = Opcode." ~ member ~ ";");
        if (cast(ushort)value == UNKNOWN_OPCODE)
            continue;
        assert(value !in opcodeNames, "Two opcodes have same value: "~ member ~" and " ~ opcodeNames[value]);
        opcodeNames[value] = member ~ " (" ~ (cast(ushort)value).to!string~")";
    }
}

unittest {
    assert(opcodeToString(cast(Opcode)UNKNOWN_OPCODE) == "<unknown opcode> 0");
}