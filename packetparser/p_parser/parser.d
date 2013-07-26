module p_parser.parser;

import std.range;
import std.stdio;
import std.conv;

import wowprotocol.packet;
import wowprotocol.opcode;
import protocol.packet;

import p_parser.dump;
import p_parser.printer;

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
            auto p = new Packet!true(packetDump.data, &(getSession(packetDump.sessionId).decompress));
            Opcode opcode = cast(Opcode)packetDump.opcode;
            writefln("%s %s %s", opcodeToString(opcode), packetDump.direction, packetDump.dateTime.to!string);
            //writefln("%s", p.toHex());
            if (!wowprotocol.packet.hasOpcodeHandler(opcode))
            {
                writeln("No opcode handler for packet");
                continue;
            }
            void[] data = read(p, opcode);
            writefln("%s", print(opcode, data));
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

