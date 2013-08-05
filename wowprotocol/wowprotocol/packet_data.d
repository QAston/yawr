/++
 + This module handles access to util.protocol.packet_stream_data_.* packet handlers
 +/
module wowprotocol.packet_data;

/// import all packet_data_.* modules
public import wowprotocol.packet_data_.session;

import util.protocol.packet_stream;
import wowprotocol.opcode;
import util.traits;
import util.protocol.direction;
import util.protocol.packet_data;

struct PacketInfo(Opcode OPCODE)
{
    enum op = OPCODE;
}

struct PacketInfo(Opcode OPCODE, Direction DIR)
{
    enum op = OPCODE;
    enum dir = DIR;
}

version(unittest)
{
import std.traits;
import std.conv;

private struct PacketDataEntry {
    TypeInfo typeInfo;
    void function(PacketStream!true) inputHandler;
    void function(PacketStream!false) outputHandler;
}

private static PacketDataEntry*[2][Opcode] handlers;

static this()
{
    foreach(opcodeString;__traits(allMembers, Opcode))
    {
        mixin("Opcode opcode = Opcode." ~ opcodeString ~ ";");
        if (cast(ushort)opcode == UNKNOWN_OPCODE)
            continue;

        foreach(Direction dir; EnumMembers!Direction)
        {
            void registerOpcodeHandler(alias packetDataType)()
            {
                handlers[opcode][dir] = PacketDataEntry(typeid(packetDataType), &packetDataType.stream!true, &packetDataType.stream!false);
            }
        }
    }
}
/+
 + Checks if opcode handler is present
 +/
private bool canStreamPacket(Opcode op, Direction dir)
{
    return getEntry(op,dir) !is null;
}

private PacketDataEntry* getEntry(Opcode op, Direction dir)
{
    auto dirs = op in handlers;
    if (dirs is null)
        return null;
    return (*dirs)[dir];
}

/++
 + Reads packetData from a given inputStream
 +/
private void[] read(PacketStream!true inputStream, Opcode opcode, Direction dir)
in {
    assert (canStreamPacket(opcode, dir));
}
body {
    PacketDataEntry PacketDataEntry = *(handlers[opcode][dir]);
    return util.protocol.packet_data.read(inputStream, PacketDataEntry.typeInfo, PacketDataEntry.inputHandler);
}

/++
 + Writes given packetData to a outputStream
 +/
private void write(PacketStream!false outputStream, Opcode opcode, Direction dir, void[] packetData)
in {
    assert(canStreamPacket(opcode, dir));
}
body {
    PacketDataEntry PacketDataEntry = *(handlers[opcode][dir]);
    util.protocol.packet_data.write(outputStream, PacketDataEntry.typeInfo, PacketDataEntry.outputHandler, packetData);
}
}

unittest {
}