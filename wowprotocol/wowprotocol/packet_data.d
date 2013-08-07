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
    util.protocol.packet_data.testPacketData!((ubyte[] buffer)=>new PacketStream!false(buffer, &((new Session()).compress)),(ubyte[] buffer)=>new PacketStream!true(buffer, &((new Session()).decompress)))(inputData);
}

/+
 + Checks that PacketData definition works as expected with given binary input
 + Params:
 +    inputBinary - binary data to test
 +    expectedResult - data, which should be result of reading the inputBinary
 +/
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR)),Opcode OP,Direction DIR)(ubyte[] inputBinary, DATA_TYPE expectedResult)
{
    util.protocol.packet_data.testPacketData!((ubyte[] buffer)=>new PacketStream!false(buffer, &((new Session()).compress)),(ubyte[] buffer)=>new PacketStream!true(buffer, &((new Session()).decompress)))(inputBinary, expectedResult);
}

/// ditto
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR)),Opcode OP,Direction DIR)(string inputBinary, DATA_TYPE expectedResult)
{
    testPacketData(cast(ubyte[])inputBinary, expectedResult);
}