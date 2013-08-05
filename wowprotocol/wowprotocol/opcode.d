/+
 + Handles access to wowVersion dependent Opcode enum
 +/
module wowprotocol.opcode;

import wowdefs.wow_version;
import std.conv;

import util.protocol.direction;

enum UNKNOWN_OPCODE = 0x0000;
mixin ("public import wowprotocol.opcode_." ~ wowVersion.to!string() ~ ";");

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

unittest {
    assert(opcodeToString(cast(Opcode)UNKNOWN_OPCODE) == "<unknown opcode> 0");
    assert(opcodeToString(Opcode.SMSG_NEW_WORLD) == "SMSG_NEW_WORLD");
}

/+
 + Returns true if given opcode can be sent in a given direction of client-server communication
 +/
bool hasDirection(Opcode opc, Direction dir)
{
    auto str = opcodeToString(opc);
    switch(str[0])
    {
        case 'S':
            return dir == Direction.s2c;
        case 'C':
            return dir == Direction.c2s;
        case 'M':
            return true;
        default:
            return false;
    }
}

unittest {
    assert(hasDirection(cast(Opcode)UNKNOWN_OPCODE, Direction.c2s) == false);
    assert(hasDirection(cast(Opcode)UNKNOWN_OPCODE, Direction.s2c) == false);
    assert(hasDirection(Opcode.SMSG_NEW_WORLD, Direction.c2s) == false);
    assert(hasDirection(Opcode.SMSG_NEW_WORLD, Direction.s2c) == true);
    assert(hasDirection(Opcode.CMSG_CAST_SPELL, Direction.s2c) == false);
    assert(hasDirection(Opcode.CMSG_CAST_SPELL, Direction.c2s) == true);
    assert(hasDirection(Opcode.MSG_MOVE_STOP, Direction.s2c) == true);
    assert(hasDirection(Opcode.MSG_MOVE_STOP, Direction.c2s) == true);
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