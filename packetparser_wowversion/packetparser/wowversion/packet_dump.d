/+
 + This module is an interface between packetparser_app and packetparser_wowversion dll.
 + It should not contain global imports from the lib, interfacing should be minimal
 +/

module packetparser.wowversion.packet_dump;

import std.datetime;

import std.range;

enum Direction : uint { c2s = 0, s2c = 1,};

class PacketDump {
    ubyte[] data;
    uint opcode;
	Direction direction;
	SysTime dateTime;
}

extern void parse(InputRange!PacketDump packets)
{
    import packetparser.wowversion.parser;
    packetparser.wowversion.parser.parse(packets);
}