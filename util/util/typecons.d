module util.typecons;

import util.traits;

/+
 + This structure is a wrapper around enum base type
 + It provides a typesafe way to deal with flags defined in an enum
 +/
struct Flags(T) if (is (T == enum))
{
    private EnumBase!T base;
    this(T val)
    {
        base = val;
    }

    this(EnumBase!T val)
    {
        base = val;
    }

    ref Flags!T opOpAssign(string op)(Flags!T rhs){
        base = opBinary!op(rhs).base; 
        return this;
    }

    ref Flags!T opAssign(Flags!T rhs){
        base = rhs.base;
        return this;
    }

    Flags!T opBinary(string op)(Flags!T rhs) if (op ==  "|" || op ==  "&" )
    {
        auto result = mixin("base " ~ op ~ "rhs.base"); 
        return Flags!T(result); 
    }

    Flags!T opBinary(string op)(T rhs) if (op ==  "|" || op ==  "&" )
    {
        auto result = mixin("base " ~ op ~ "rhs"); 
        return Flags!T(cast(T)result); 
    }

    Flags!T opBinaryRight(string op)(T lhs){
        return Flags!T(lhs).opBinary!op(this);
    }

    TO opCast(TO)() if(is(TO == EnumBase!T))
    {
        return base;
    }

    bool opCast(TO)() if(is(TO == bool))
    {
        return base != 0;
    }

    string toString()
    {
        import std.traits;
        import std.array;
        import std.conv;
        auto app = appender!string();
        bool bar = true;
        foreach(member; EnumMembers!T)
        {
            if ((base & member) != 0)
            {
                if (!bar)
                    bar = true;
                else
                    app.put(" | ");
                app.put(member.to!string());
            }
        }
        if (!bar)
        {
            app.put("<empty>");
        }
        return app.data;
    }
}

unittest {
    enum TestFlags{
        FLAG_1 = 0x001,
        FLAG_2 = 0x002,
        FLAG_3 = 0x004,
        FLAG_4 = 0x008,
    }
    enum OtherFlags
    {
        FLAG_X = 0x8,
    }
    import std.conv;
    auto t1 = Flags!TestFlags();
    auto t2 = Flags!TestFlags(2);
    auto t3 = Flags!TestFlags(TestFlags.FLAG_4 | TestFlags.FLAG_2);
    auto t4 = Flags!TestFlags(TestFlags.FLAG_2);
    assert(t2 == t4);
    assert((t2 | TestFlags.FLAG_4) == t3);
    assert((t3 & ~TestFlags.FLAG_4) == t2);
    auto asBase = cast(int)t2;
    assert(asBase==2);
    assert(t2);
    assert(!t1);
}