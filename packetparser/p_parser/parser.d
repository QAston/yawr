module p_parser.parser;

import std.range;
import std.stdio;
import std.conv;

import protocol.handler;
import protocol.opcode;
import protocol.packet;

import p_parser.dump;
import p_parser.printer;

import protocol.session;

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
            auto p = new Packet!true(packetDump.data, cast(Opcode)packetDump.opcode, getSession(packetDump.sessionId));
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
        try {
            writeln("Error processing file: "~ ex.msg);
        }
        catch ( Exception ex) {
        }
    }
}

