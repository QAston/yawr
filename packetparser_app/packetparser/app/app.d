module packetparser.app.app;

import core.runtime;
import std.c.windows.windows;
import std.stdio;
import std.algorithm;
import std.range;
import std.traits;

import packetparser.app.input;
import packetparser.wowversion.packet_dump;

import util.dll;

mixin (importDynamically!(packetparser.wowversion.packet_dump));

import vibe.core.file;

int main(string[] args)
{
    args.popFront;
    string[] files = args;

    writeln("Start Dynamic Link...\n");

    HMODULE h = cast(HMODULE) Runtime.loadLibrary("yawr_packetparser_wowversion.dll");

    if (h is null)
    {
        writeln("error loading mydll.dll\n");
        return 1;
    }

    FARPROC fp = GetProcAddress(h, mangledSymbol!(packetparser.wowversion.packet_dump.getParser));

    pragma(msg, mangledSymbol!(packetparser.wowversion.packet_dump.getParser));

    if (fp is null)
    {
        writeln("error loading symbol getMyClass()\n");
        return 1;
    }

    auto parsePackets = (cast(typeof(&getParser)) fp)();
    foreach (f; files)
    {
        FileStream stream = openFile(f, FileMode.read);
        PacketInput packets = new PktPacketInput(stream);

        (*parsePackets)(packets);
    }

    if (!Runtime.unloadLibrary(h))
    {
        writeln("error freeing mydll.dll\n");
        return 1;

    }
    writeln("End...\n");
    return 0;
}