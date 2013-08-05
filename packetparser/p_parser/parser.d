module p_parser.parser;

import std.range;
import std.stdio;
import std.conv;

import wowprotocol.opcode;
import util.protocol.packet_stream;

import p_parser.dump;
import p_parser.packet_data;

import wowprotocol.session;

static Session[uint] sessions;

Session getSession(uint sessionId)
{
    Session* session =  sessionId in sessions;
    if (session)
        return *session;
    sessions[sessionId] = new Session();
    return sessions[sessionId];
}

void parse(InputRange!PacketDump packets) nothrow
{
    try {
        foreach(packetDump; packets)
        {
            auto p = new PacketStream!true(packetDump.data, &(getSession(packetDump.sessionId).decompress));
            Opcode opcode = cast(Opcode)packetDump.opcode;
            writefln("%s %s %s", opcodeToString(opcode), packetDump.direction, packetDump.dateTime.to!string);
            if (!canParse(opcode, packetDump.direction))
            {
                writeln("No opcode handler for packet");
                continue;
            }
            writefln("%s", p.toHex());
            void[] data = read(p, opcode, packetDump.direction);
            writefln("%s", print(opcode, packetDump.direction, data));
            stdin.readln();
        }
    }
    catch(Exception ex)
    {
        try {
            writeln("Error processing file: "~ ex.msg);
        }
        catch ( Exception ex) {
        }
    }
}


