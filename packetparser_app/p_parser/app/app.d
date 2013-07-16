/+
 + This is an entry module for packet parser app.
 +
 + Packet parser consists of the app - this exec and packet parser WowVersion-specific modules.
 + Each version-module is a DLL handling processing of packet data according to WowVersion which it was compiled for
 + The app handles loading files into the parser and directing loaded packets into modules.
 +/
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
import util.wow_versions;

mixin (importDynamically!(p_parser.dump));

import vibe.core.file;

int main(string[] args)
{
    args.popFront;
    string[] files = args;

    foreach (f; files)
    {
        FileStream stream = openFile(f, FileMode.read);
        PacketInput packets = new PktPacketInput(stream);
        if (packets.empty())
            writeln("");

        auto parsePackets = getParseFunction(packets.getBuild());
        (*parsePackets)(packets);
    }

    return 0;
}


struct ParserModule {

    HMODULE handler;
    ReturnType!getParser parseFunction;
}

string getModuleName(int wowVersion)
in {
    assert(wowVersion != WowVersion.Undefined);
}
body {
    import std.conv;
    return "yawr_packetparser_" ~ std.conv.to!string(wowVersion) ~ ".dll";
}

shared immutable(ParserModule)[int] parserModules;

immutable(ReturnType!getParser) getParseFunction(int wowVersion)
in {
    assert(wowVersion != WowVersion.Undefined);
}
body {
    auto parserModule = wowVersion in parserModules;
    if (parserModule is null)
    {
        string libraryName = getModuleName(wowVersion);
        ParserModule newModule;
        newModule.handler = cast(HMODULE) Runtime.loadLibrary(".dll");
        if (newModule.handler is null)
            return null;

        FARPROC fp = GetProcAddress(newModule.handler, mangledSymbol!(p_parser.dump.getParser));
        if (fp is null)
            throw new Exception("");

        newModule.parseFunction = (cast(typeof(&getParser)) fp)();

        parserModules[wowVersion] = immutable(ParserModule)(cast(immutable)newModule.handler, newModule.parseFunction);

        return newModule.parseFunction;
    }
    return parserModule.parseFunction;
}

shared static ~this()
{
    foreach (wowVer, prserModule;parserModules)
    {
        auto result = Runtime.unloadLibrary(cast(void*)(prserModule.handler));
        if (!result)
            throw new Exception("");
    }
}