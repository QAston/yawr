/+
 + This module is an interface between packetparser_app and packetparser dll.
 + It should not contain global imports from the lib, interfacing should be minimal
 +/

module p_parser.dump;

import std.datetime;

import util.protocol.direction;

import std.range;

struct PacketDump {
    ubyte[] data;
    uint opcode;
    util.protocol.direction.Direction direction;
    SysTime dateTime;
    uint sessionId;
}

export void function (InputRange!PacketDump) nothrow getParser() 
{
    import p_parser.parser;
    static assert(is(typeof(&parse) == typeof(return)));
    return &parse;
}