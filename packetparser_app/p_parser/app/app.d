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
import wowdefs.wow_versions;

version(PacketParserDLL)
    mixin (importDynamically!(p_parser.dump));

int main(string[] args)
{
    args.popFront;
    string[] files = args;

    foreach (f; files)
    {
        try {
            PacketInput packets = getPacketInput(f);
            if (!packets.empty())
            {
                auto parsePackets = getParseFunction(packets.getBuild());
                (*parsePackets)(packets);
            }
        }
        catch (Exception ex)
        {
            writeln("Error processing file: " ~ f ~ " Message: "~ ex.msg);
        }
    }

    return 0;
}

version(PacketParserDLL)
{
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

/+
 + Returns a function which can parse packets in a way specific to given wowVersion
 +/
immutable(ReturnType!getParser) getParseFunction(int wowVersion)
in {
    assert(wowVersion != WowVersion.Undefined);
}
out (result) {
    assert(result !is null);
}
body {
    import std.conv;
    auto parserModule = wowVersion in parserModules;
    if (parserModule is null)
    {
        string libraryName = getModuleName(wowVersion);
        ParserModule newModule;
        newModule.handler = cast(HMODULE) Runtime.loadLibrary(libraryName);
        if (newModule.handler is null)
            throw new Exception("Unsupported wowVersion: " ~ wowVersion.to!string ~". Could not load library: " ~ libraryName);

        auto symbol =  mangledSymbol!(p_parser.dump.getParser);
        FARPROC fp = GetProcAddress(newModule.handler,symbol);
        if (fp is null)
            throw new Exception("Could not load symbol: "~ *symbol ~ " from library: " ~ libraryName);

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
            throw new Exception("Could not unload library: "~ getModuleName(wowVer));
    }
}
}
else
{
/+
 + Returns a function which can parse packets in a way specific to given wowVersion
 +/
immutable(ReturnType!getParser) getParseFunction(int wowVersion)
in {
    assert(wowVersion != WowVersion.Undefined);
}
out (result) {
    assert(result !is null);
}
body {
    import wowdefs.wow_version;
    static if (wowVersion != wowdefs.wow_version.wowVersion)
        throw new Exception("Unsupported wowVersion: " ~ wowVersion.to!string ~". Could not load library: " ~ libraryName);
    return getParser();
}
}