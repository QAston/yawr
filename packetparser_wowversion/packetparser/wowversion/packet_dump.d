/+
 + This module is an interface between packetparser_app and packetparser_wowversion dll.
 + It should not contain global imports from the lib, interfacing should be minimal
 +/

module packetparser.wowversion.packet_dump;

import std.datetime;

import std.range;

enum Direction : uint { c2s = 0, s2c = 1,};

struct PacketDump {
    ubyte[] data;
    uint opcode;
	Direction direction;
	SysTime dateTime;
}

export void function (InputRange!PacketDump) nothrow getParser() 
{
    import packetparser.wowversion.parser;
    static assert(is(typeof(&parse) == typeof(return)));
    return &parse;
}