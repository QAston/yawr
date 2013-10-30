/+
 + This module provides basic functionality for PacketData template types
 +/
module util.protocol.packet_data;

/++
 + Reads a packet data of a specified structType from a given inputStream using given func
 +/
void[] read(PACKET_STREAM)(PACKET_STREAM inputStream, TypeInfo structType, void function(PACKET_STREAM) func) if (PACKET_STREAM.isInput)
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

    void delegate(PACKET_STREAM) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = func;
    caller(inputStream);
    return packetData;
}

/++
 + Writes packetData to a given outputStream using given func
 +/
void write(PACKET_STREAM)(PACKET_STREAM outputStream, TypeInfo structType, void function(PACKET_STREAM) func, void[] packetData) if (PACKET_STREAM.isOutput)
in {
    assert(outputStream !is null);
    assert(structType !is null);
    assert(func !is null);
    assert(packetData !is null);
}
body {
    assert(packetData.length == structType.tsize());
    void delegate(PACKET_STREAM) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = func;
    caller(outputStream);
}


/+
+ Checks that PacketData can be written to stream and reread from it and have same value
+/
void testPacketData(alias GET_OUTPUT_STREAM, alias GET_INPUT_STREAM, DATA_TYPE)(DATA_TYPE inputData)
{
    import util.test;
    import std.stdio;
    import util.struct_printer;
    alias typeof(inputData) PacketDataType;
    mixin(test!("WowProtocol-"~PacketDataType.stringof));

    scope(failure)
    {
        writeln("Input packet data:");
        writeln(fieldsToString(inputData));
    }

    // generate outputBinary from outputPacketData
    ubyte outputBinary[] = new ubyte[1024*1024*4];
    auto outputStream = GET_OUTPUT_STREAM(outputBinary);
    scope(failure)
    {
        writeln("Output binary:");
        writeln(outputStream.toHex);
    }
    outputStream.val(inputData);

    PacketDataType outputPacketData;
    scope(failure)
    {
        writeln("Output packet data:");
        writeln(fieldsToString(outputPacketData));
    }
    // generate outputPacketData from inputBinary
    auto inputStream = GET_INPUT_STREAM(outputStream.getData());
    inputStream.val(outputPacketData);
    assert(outputPacketData == inputData);
}


/+
+ Checks that PacketData definition works as expected with given binary input
+ Params:
+    inputBinary - binary data to test
+    expectedResult - data, which should be result of reading the inputBinary
+/
void testPacketData(alias GET_OUTPUT_STREAM, alias GET_INPUT_STREAM, DATA_TYPE)(ubyte[] inputBinary, DATA_TYPE expectedResult)
{
    import util.test;
    import std.stdio;
    import util.struct_printer;
    alias typeof(expectedResult) PacketDataType;
    mixin(test!("WowProtocol-"~PacketDataType.stringof));

    PacketDataType outputPacketData;
    // generate outputPacketData from inputBinary
    auto inputStream = GET_INPUT_STREAM(inputBinary);
    scope(failure)
    {
        writeln("Input binary:");
        writeln(inputBinary.toHex);
        writeln("Expected result:");
        writeln(fieldsToString(expectedResult));
    }
    inputStream.val(outputPacketData);
    assert(outputPacketData == expectedResult);
    scope(failure)
    {
        writeln("Output packet data:");
        writeln(fieldsToString(outputPacketData));
    }
    // generate outputBinary from outputPacketData
    ubyte outputBinary[] = new ubyte[inputBinary.length*4];
    auto outputStream = GET_OUTPUT_STREAM(outputBinary);
    scope(failure)
    {
        writeln("Output binary:");
        writeln(outputStream.toHex);
    }
    outputStream.val(outputPacketData);

    assert(outputStream.getData() == inputBinary);
}

/+
 + Default implementation of PacketData.stream function
 + Makes structure to be laid down in stream exactly as in memory
 + Therefore no reference types or pointers or alignmenr allowed
 +/
mixin template streamAsRawBytes()
{
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}