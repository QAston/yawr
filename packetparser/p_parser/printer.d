module p_parser.printer;

import std.traits;

import wowprotocol.opcode;
import wowprotocol.packet_data;
import std.typetuple;
import util.traits;

string fieldsToString(T)(in T t, in string alignment="")
{
    import std.array;
    import std.range;
    auto str = appender!string();
    static if (isSomeString!T || isSomeChar!T)
    {
        str.put(alignment);
        str.put(t);
        str.put("\n");
    }
    else static if (is(T : U[], U) && isSomeChar!U)
    {
        str.put(alignment);
        foreach(i, element; t)
        {
            put(element);
        }
        str.put("\n");
    }
    else static if (is(T == Opcode))
    {
        str.put(alignment);
        str.put(opcodeToString(t));
        str.put("\n");
    }
    else static if (is(T BASE == enum))
    {
        str.put(alignment);
        str.put(std.conv.to!string(t));
        str.put(" (");
        str.put(std.conv.to!string(cast(BASE)t));
        str.put(")");
        str.put("\n");
    }
    else static if (isBasicType!(T))
    {
        str.put(alignment);
        str.put(std.conv.to!string(t));
        str.put("\n");
    }
    else static if (isForwardRange!T || isArray!T)
    {
        static if (isForwardRange!T)
            auto range = t.save;
        else
            auto range = t;

        foreach(i, element; t)
        {
            str.put(alignment);
            str.put("[");
            str.put(std.conv.to!string(i));
            str.put("]: \n");
            str.put(element.fieldsToString(alignment ~ "\t"));
        }
    }
    else 
    {
        import std.regex;
        enum ctr = ctRegex!(`[^\.]*?$`);
        foreach (i, a; t.tupleof)
        {
            str.put(alignment);
            auto m2 = match(t.tupleof[i].stringof, ctr);
            str.put(std.conv.to!string(m2.captures[0]));
            str.put(": \n");
            str.put(fieldsToString(a, alignment ~ "\t"));
        }
    }
    return str.data();
}

unittest {
    import std.stdio;
    enum Enumerator {
        A = 1,
        B = 40,
    }
    struct A {
        struct C {
            int i = -7;
            string j = "tyry";
        }
        uint a = 54;
        bool b = true;
        C c;
        C[4] d;
        alias C D;
        Enumerator e;
    }

    struct B{
        bool b;
    }
    fieldsToString(B());
    fieldsToString(A());
}

private static string function(void[])[Opcode] packetPrinters;

string print(Opcode opcode, void[] data)
in {
    assert (canStreamPacket(opcode));
}
body {
    return packetPrinters[opcode](data);
}

string packetPrinter(T)(void[] data)
{
    import std.stdio;
    assert(T.sizeof == data.length);
    return fieldsToString!(T)(*(cast(T*)data));
}

static this()
{
    foreach(opcodeString;__traits(allMembers, Opcode))
    {
        mixin("Opcode opcode = Opcode." ~ opcodeString ~ ";");
        if (cast(ushort)opcode == UNKNOWN_OPCODE)
            continue;

        mixin(q{
            static if(__traits(compiles, PacketData!(PacketInfo!(Opcode.}~ opcodeString ~q{))))
            {
                mixin("alias PacketData!(PacketInfo!(Opcode."~ opcodeString ~")) packetDataType;");

                packetPrinters[opcode] = &packetPrinter!(packetDataType);
            }});
    }
}