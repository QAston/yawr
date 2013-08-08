module util.struct_printer;

import std.typetuple;
import util.traits;
import std.traits;

/+
 + Generates a string representation of a given struct
 + Prints member names and uses more whitespace than builtin toString
 +/
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

/+
+ Returns string with a hex dump of a stream
+/
public string toHex(ubyte[] data)
{
    import std.ascii, std.format;
    import std.array;

    auto dump = appender!(dchar[]);

    dump.put("|-------------------------------------------------|---------------------------------|\n");
    dump.put("| 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F | 0 1 2 3 4 5 6 7 8 9 A B C D E F |\n");
    dump.put("|-------------------------------------------------|---------------------------------|\n");

    for (auto i = 0; i < data.length; i += 16)
    {
        auto text = appender!(dchar[]);
        auto hex = appender!(dchar[]);
        text.put("| ");
        hex.put("| ");

        for (auto j = 0; j < 16; j++)
        {
            if (j + i < data.length)
            {
                auto val = data[j + i];
                formattedWrite(hex , "%02X ", val);

                if (val.isPrintable)
                    text.put(val);
                else
                    text.put(".");

                text.put(" ");
            }
            else
            {
                hex.put("   ");
                text.put("  ");
            }
        }


        hex.put(text.data ~ "|");
        hex.put("\n");
        dump.put(hex.data);
    }


    dump.put("|-------------------------------------------------|---------------------------------|");
    return std.conv.to!string(dump.data());
}
