module p_parser.app.app;

import core.runtime;
import std.c.windows.windows;
import std.stdio;
import std.algorithm;
import std.range;
import std.traits;

import p_parser.app.input;
import p_parser.dump;

import util.dll;

mixin (importDynamically!(p_parser.dump));

import vibe.core.file;

int main(string[] args)
{
    args.popFront;
    string[] files = args;

    writeln("Start Dynamic Link...\n");

    HMODULE h = cast(HMODULE) Runtime.loadLibrary("yawr_packetparser.dll");

    if (h is null)
    {
        writeln("error loading mydll.dll\n");
        return 1;
    }

    FARPROC fp = GetProcAddress(h, mangledSymbol!(p_parser.dump.getParser));

    pragma(msg, mangledSymbol!(p_parser.dump.getParser));

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