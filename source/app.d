module app;

import std.stdio;
import std.algorithm;
import std.range;
import std.conv;

import util;
import input;

import protocol.opcode;

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
            stdin.readln();
        }
    }
}