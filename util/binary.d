module util.binary;

public import std.bitmanip;
public import std.system;
import std.traits;

/+
 + Utility for accessing data as bit array
 + Structure members must be aligned to one byte boundary (align(1))
 +/
BitArray asBitArray(T)(ref T t)
{
    static assert(!hasIndirections!T, "Cannot get bitwise access to types with indirections!");
    static if (is(T==struct))
    {
        import util.traits;
        enum size = MembersSize!T;
        static assert(size == RepresentationMembersSize!T && size == T.sizeof, "Alignment error, structure is not aligned for casting to ubyte[]");
    }
    else
        enum size = T.sizeof;
    auto bits = BitArray();
    void[] data = (&t)[0..size];
    bits.init(cast(void[])data, size*8);
    return bits;
}

/+
 + Structure used to represent Bit as a distinct type from bool.
 + Can be implicitly cast to bool, explicitly to any integral type
 +/
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
 + Structure members must be aligned to one byte boundary (align(1))
 +/
ubyte[] asByteArray(T)(ref T t)
{
    static assert(!hasIndirections!T, "Cannot get bitwise access to types with indirections!");

    static if (is(T==struct))
    {
        import util.traits;
        enum size = MembersSize!T;
        static assert(size == RepresentationMembersSize!T && size == T.sizeof, "Alignment error, structure is not aligned for casting to ubyte[]");
    }
    else
        enum size = T.sizeof;

    ubyte[] data = (cast(ubyte*)(&t))[0..size];
    return data;
}

unittest {
    ulong a= 0x11223344;
    assert(asByteArray(a)[0] == 0x44);
    assert(asByteArray(a)[1] == 0x33);
    assert(asByteArray(a)[2] == 0x22);
    assert(asByteArray(a)[3] == 0x11);

    align(1)
    struct TestType {
        align(1):
        ubyte a;
        ushort b;
    }
    auto t1 = TestType(0x5, 0x1423);
    assert(asByteArray(t1)[0] == 0x5);
    assert(asByteArray(t1)[1] == 0x23);
    assert(asByteArray(t1)[2] == 0x14);
}

/++
+ Casts a hex literal x"" from string to ubyte[] - prevents runtime utf validation
+ Should not be used on non-literal strings!
+/
ubyte[] bin(string hexLiteral)()
{
    return cast(ubyte[])hexLiteral;
}

///
unittest {
    static assert(is (typeof(x"90") == string));
    auto a = bin!x"90";
    static assert(is (typeof(a) == ubyte[]));
}