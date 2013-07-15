module packetparser.wowversion.parser;

import std.range;
import std.stdio;
import std.conv;

import protocol.handler;
import protocol.opcode;
import protocol.packet;

import packetparser.wowversion.packet_dump;
import packetparser.wowversion.printer;;


void parse(InputRange!PacketDump packets) nothrow
{
    try {
        foreach(packetDump; packets)
        {
            auto p = new Packet!true(packetDump.data, cast(Opcode)packetDump.opcode);
            writefln("%s %s %s", p.opcode.opcodeToString, packetDump.direction, packetDump.dateTime.to!string);
            writefln("%s", p.toHex());
            if (!protocol.handler.hasOpcodeHandler(p.opcode))
            {
                writeln("No opcode handler for packet");
                stdin.readln();
                continue;
            }
            void[] data = read(p, p.opcode);
            writefln("%s", print(p.opcode, data));
            stdin.readln();
        }
    }
    catch(Exception ex)
    {
    }
}