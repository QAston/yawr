/++
 + This module handles access to util.protocol.packet_stream_data_.* packet handlers
 +/
module wowprotocol.packet_data;

/// import all packet_data_.* modules
public import wowprotocol.packet_data_.session;

import util.protocol.packet_stream;
import wowprotocol.opcode;
import util.traits;

private struct HandlerEntry {
    TypeInfo typeInfo;
    void function(PacketStream!true) inputHandler;
    void function(PacketStream!false) outputHandler;
}

private static HandlerEntry[Opcode] handlers;

struct PacketInfo(Opcode OPCODE)
{
    enum opcode = OPCODE;
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

            handlers[opcode] = HandlerEntry(typeid(packetDataType), &packetDataType.stream!true, &packetDataType.stream!false);
        }});
    }
}
/+
 + Checks if opcode handler is present
 +/
bool canStreamPacket(Opcode op)
{
    return (op in handlers) !is null;
}

/++
 + Reads packetData from a given packet stream
 +/
void[] read(PacketStream!true packet, Opcode opcode)
in {
    assert (canStreamPacket(opcode));
}
body {

    HandlerEntry handlerEntry = handlers[opcode];
    void[] packetData = void;
    if (handlerEntry.typeInfo.init().ptr is null)
    {
        packetData = cast(void[])new ubyte[handlerEntry.typeInfo.tsize()];
    }
    else
    {
        packetData = (handlerEntry.typeInfo.init()).dup;
    }

    void delegate(PacketStream!true) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = handlerEntry.inputHandler;
    caller(packet);
    return packetData;
}

/++
 + Writes given packetData to a packet stream
 +/
void write(PacketStream!false packet, Opcode opcode, void[] packetData)
in {
    assert (canStreamPacket(opcode));
}
body {
    HandlerEntry handlerEntry = handlers[opcode];
    assert(packetData.length == handlerEntry.typeInfo.tsize());
    void delegate(PacketStream!false) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = handlerEntry.outputHandler;
    caller(packet);
}

unittest {
}