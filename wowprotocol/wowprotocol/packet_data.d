/++
 + This module handles access to util.protocol.packet_stream_data_.* packet handlers
 +/
module wowprotocol.packet_data;

/// import all packet_data_.* modules
public import wowprotocol.packet_data_.session;

import util.protocol.packet_stream;
import wowprotocol.opcode;
import wowprotocol.session;
import util.traits;
import util.protocol.direction;
import util.protocol.packet_data;

struct PacketInfo(Opcode OPCODE, Direction DIR)
{
    enum op = OPCODE;
    enum dir = DIR;
}

/+
 + Checks that PacketData can be written to stream and reread from it and have same value
 +/
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR)),Opcode OP,Direction DIR)(DATA_TYPE inputData)
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
    auto outputStream = new PacketStream!false(outputBinary, &((new Session()).compress));
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
    auto inputStream = new PacketStream!true(outputStream.getData(), &((new Session()).decompress));
    inputStream.val(outputPacketData);
    assert(outputPacketData == inputData);
}


/+
 + Checks that PacketData definition works as expected with given binary input
 + Params:
 +    inputBinary - binary data to test
 +    expectedResult - data, which should be result of reading the inputBinary
 +/
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR)),Opcode OP,Direction DIR)(ubyte[] inputBinary, DATA_TYPE expectedResult)
{
    import util.test;
    import std.stdio;
    import util.struct_printer;
    alias typeof(expectedResult) PacketDataType;
    mixin(test!("WowProtocol-"~PacketDataType.stringof));

    PacketDataType outputPacketData;
    // generate outputPacketData from inputBinary
    auto inputStream = new PacketStream!true(inputBinary, &((new Session()).decompress));
    scope(failure)
    {
        writeln("Input binary:");
        writeln(inputStream.toHex);
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
    auto outputStream = new PacketStream!false(outputBinary, &((new Session()).compress));
    scope(failure)
    {
        writeln("Output binary:");
        writeln(outputStream.toHex);
    }
    outputStream.val(outputPacketData);

    assert(outputStream.getData() == inputBinary);
}

/// ditto
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR)),Opcode OP,Direction DIR)(string inputBinary, DATA_TYPE expectedResult)
{
    testPacketData(cast(ubyte[])inputBinary, expectedResult);
}