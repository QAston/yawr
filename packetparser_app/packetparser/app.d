module app;

import std.stdio;
import std.algorithm;
import std.range;
import std.conv;

import util.time;
import input;
import packet_printer;

import protocol.opcode;
import protocol.handler;

import vibe.core.file;

void main(string[] args)
{
    args.popFront;
    string[] files = args;

    foreach (f; files)
    {
        FileStream stream = openFile(f, FileMode.read);
        PacketInput packets = new PktPacketInput(stream);

        foreach (p; packets)
        {
            writefln("%s %s %s", p.opcode.opcodeToString, p.direction, p.dateTime.to!string);
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
}