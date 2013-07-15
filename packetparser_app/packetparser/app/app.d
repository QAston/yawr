module packetparser.app.app;

import std.stdio;
import std.algorithm;
import std.range;

import packetparser.app.input;
import packetparser.wowversion.packet_dump;

import vibe.core.file;

void main(string[] args)
{
    args.popFront;
    string[] files = args;

    foreach (f; files)
    {
        FileStream stream = openFile(f, FileMode.read);
        PacketInput packets = new PktPacketInput(stream);

        
    }
}