/+
 + This module provides basic functionality for PacketData template types
 +/
module util.protocol.packet_data;

import util.protocol.packet_stream;

/++
 + Reads a packet data of a specified structType from a given inputStream using given func
 +/
void[] read(PacketStream!true inputStream, TypeInfo structType, void function(PacketStream!true) func)
in {
    assert(inputStream !is null);
    assert(structType !is null);
    assert(func !is null);
}
out(packetData) {
    assert(packetData !is null);
}
body {
    void[] packetData = void;
    if (structType.init().ptr is null)
        packetData = cast(void[])new ubyte[structType.tsize()];
    else
        packetData = (structType.init()).dup;

    void delegate(PacketStream!true) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = func;
    caller(inputStream);
    return packetData;
}

/++
 + Writes packetData to a given outputStream using given func
 +/
void write(PacketStream!false outputStream, TypeInfo structType, void function(PacketStream!false) func, void[] packetData)
in {
    assert(outputStream !is null);
    assert(structType !is null);
    assert(func !is null);
    assert(packetData !is null);
}
body {
    assert(packetData.length == structType.tsize());
    void delegate(PacketStream!false) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = func;
    caller(outputStream);
}