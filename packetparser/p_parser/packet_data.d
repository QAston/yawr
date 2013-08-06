/+
 + This module provides functions for operating on PacketData structures
 +/
module p_parser.packet_data;

import std.traits;
import std.typecons;

import wowprotocol.packet_data;
import wowprotocol.opcode;

import util.struct_printer;
import util.protocol.packet_data;
import util.protocol.direction;
import util.protocol.packet_stream;

/+
 + Converts packet with given opcode and dir to string representation
 +/
string print(Opcode opcode, Direction dir, void[] data)
in {
    assert (canParse(opcode, dir));
}
body {
    return packetDataEntries[opcode][dir].convertToString(data);
}

/+
 + Reads packet with given opcode and dir from stream
 +/
void[] read(PacketStream!true inputStream, Opcode opcode, Direction dir)
in {
    assert (canParse(opcode, dir));
}
body {
    Nullable!PacketDataEntry entry = getEntry(opcode, dir);
    return util.protocol.packet_data.read(inputStream, entry.typeInfo, entry.readFromStream);
}
/+
 + Checks if packet with given opcode and dir has parsing functions
 +/
bool canParse(Opcode op, Direction dir)
{
    return !(getEntry(op, dir).isNull);
}

private struct PacketDataEntry
{
    TypeInfo typeInfo;
    string function(void[]) convertToString;
    void function(PacketStream!true) readFromStream;
}

private static Nullable!(PacketDataEntry)[2][Opcode] packetDataEntries;

private Nullable!PacketDataEntry getEntry(Opcode op, Direction dir)
{
    auto dirs = op in packetDataEntries;
    if (dirs is null)
        return Nullable!PacketDataEntry();
    return (*dirs)[dir];
}

private void setEntry(Opcode op, Direction dir, PacketDataEntry entry)
{
    auto dirs = op in packetDataEntries;
    if (dirs is null)
    {
        packetDataEntries[op] = typeof(*dirs).init;
    }
    packetDataEntries[op][dir] = entry;
}

private string packetPrinter(T)(void[] data)
{
    assert(T.sizeof == data.length);
    return fieldsToString!(T)(*(cast(T*)data));
}

static this()
{
    import std.conv;
    foreach(opcodeString;__traits(allMembers, Opcode))
    {
        mixin("Opcode opcode = Opcode." ~ opcodeString ~ ";");
        if (cast(ushort)opcode == UNKNOWN_OPCODE)
            continue;

        foreach(Direction dir; EnumMembers!Direction)
        {
            if (hasDirection(opcode, dir))
            {
                string generateCheck(string type)()
                {
                    return q"[
                        static if(__traits(compiles,]" ~ type ~ q"[))
                        {
                            alias ]" ~ type ~ q"[ packetDataType;
                            setEntry(opcode, dir, PacketDataEntry(typeid(packetDataType), &packetPrinter!(packetDataType), &packetDataType.stream!(PacketStream!true)));
                        }]";
                }

                mixin(generateCheck!("PacketData!(PacketInfo!(Opcode."~ opcodeString  ~", Direction."~dir.to!string~"))"));
            }
        }
    }
}