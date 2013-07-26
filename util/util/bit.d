module util.bit;
/+
 + Returns BitArray providing bitwise access to given type
 +/
import std.bitmanip;
import std.traits;

BitArray asBitArray(T)(ref T t)
{
    static assert(!hasIndirections!T, "Cannot get bitwise access to types with indirections!");
    auto bits = BitArray();
    void[] data = (&t)[0..T.sizeof];
    bits.init(cast(void[])data, T.sizeof*8);
    return bits;
}

struct Bit {
    this(T)(T v) if (isIntegral!T)
    {
        val = v != 0;
    }
    this(T)(T v) if (is (T == bool) )
    {
        val = v;
    }
    bool val;
    alias val this;
}

unittest {
    import util.test;
    mixin (test!("Bit"));
    import std.conv;
    auto a = Bit(false);
    auto b = Bit(true);
    assert(a.to!int() == 0);
    assert(a.to!uint() == 0);
    assert(a.to!ubyte() == 0);
    assert(cast(uint)a == 0);
    assert(b.to!int() == 1);
    assert(b.to!uint() == 1);
    assert(b.to!ubyte() == 1);
    assert(cast(uint)b == 1);
    ubyte c = 0;
    ubyte d = 1;
    assert(c.to!Bit() == false);
    assert(d.to!Bit() == true);
}

/+
 + Utility for accessing data as byte array
 +/
ubyte[] asByteArray(T)(ref T t)
{
    static assert(!hasIndirections!T, "Cannot get bitwise access to types with indirections!");
    ubyte[] data = (cast(ubyte*)(&t))[0..T.sizeof];
    return data;
}

unittest {
    ulong a= 0x11223344;
    assert(asByteArray(a)[0] == 0x44);
    assert(asByteArray(a)[1] == 0x33);
    assert(asByteArray(a)[2] == 0x22);
    assert(asByteArray(a)[3] == 0x11);
}
