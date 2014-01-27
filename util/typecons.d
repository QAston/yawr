module util.typecons;

public import std.typecons;
import std.exception;
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

    ref Flags!T opOpAssign(string op)(T rhs){
        base = opBinary!op(rhs).base; 
        return this;
    }

    ref Flags!T opAssign(Flags!T rhs){
        base = rhs.base;
        return this;
    }

    ref Flags!T opAssign(T rhs){
        base = rhs;
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

/// Returns empty array of given type
auto emptyArray(T)() @trusted
{
    return (cast(T*) 1)[0 .. 0];
}

///
unittest {
    assert (emptyArray!int !is null);
    assert((emptyArray!int).length == 0);
}

/// Returns newly created struct wrapped in a nullable with args passed to struct constructor
auto nullable(T, ARGS...)(ARGS args) if (is(T==struct))
{
    return Nullable!(T)(T(args));
}

/// ditto
auto nullable(T, VAL)(VAL args) if (isBuiltinType!T)
{
    T a = args;
    return Nullable!(T)(a);
}

///
unittest {
    struct A
    {
        int a;
    }
    auto a = nullable!A(5);
    static assert(is (typeof(a) == Nullable!A));
    assert(a.get().a == 5);
    assert(!a.isNull());
}

///
unittest {
    auto a = nullable!int(5);
    static assert(is (typeof(a) == Nullable!int));
    assert(a.get() == 5);
    assert(!a.isNull());
}

/+
 + A wrapper around phobos's nullable
 + Adds better toString and opEquals
 +/
struct Optional(T)
{
    private std.typecons.Nullable!T val;

    /**
    Constructor initializing $(D this) with $(D value).
    */
    pure this()(inout T value) inout  // proper signature
    {
        val = std.typecons.Nullable!T(value);
    }

    /**
    Returns $(D true) if and only if $(D this) is in the null state.
    */
    @property bool isNull() const pure nothrow @safe
    {
        return val.isNull;
    }

    /**
    Forces $(D this) to the null state.
    */
    void nullify()()
    {
        val.nullify();
    }

    /**
    Assigns $(D value) to the internally-held state. If the assignment
    succeeds, $(D this) becomes non-null.
    */
    void opAssign()(T value)
    {
        val.opAssign(value);
    }

    string toString()
    {
        import std.conv;
        if (val.isNull)
            return "<null>";
        return val.get.to!string();
    }

    bool opEquals()(auto ref const Optional!T s) const 
    {
        if (val.isNull && s.val.isNull)
            return true;
        if (val.isNull || s.val.isNull)
            return false;
        return get() == s.get();
    }

    bool opEquals()(auto ref const T s) const 
    {
        return get() == s;
    }


    /**
    Gets the value. $(D this) must not be in the null state.
    This function is also called for the implicit conversion to $(D T).
    */
    @property ref inout(T) get() inout pure nothrow @safe
    {
        return val.get;
    }

    /**
    Implicitly converts to $(D T).
    $(D this) must not be in the null state.
    */
    alias get this;
}

unittest {
    Optional!int a;
    assert(a.isNull);
    assertThrown!Throwable(a.get);
    a = 5;
    assert(!a.isNull);
    assert(a == 5);
    assert(a != 3);
    assert(a.get != 3);
    a.nullify();
    assert(a.isNull);
    a = 3;
    assert(a == 3);
    a *= 6;
    assert(a == 18);
    a = a;
    assert(a == 18);
    a.nullify();
    assertThrown!Throwable(a += 2);
}
unittest
{
    auto k = Optional!int(74);
    assert(k == 74);
    k.nullify();
    assert(k.isNull);
}
unittest
{
    static int f(in Optional!int x) {
        return x.isNull ? 42 : x.get;
    }
    Optional!int a;
    assert(f(a) == 42);
    a = 8;
    assert(f(a) == 8);
    a.nullify();
    assert(f(a) == 42);
}
unittest
{
    static struct S { int x; }
    Optional!S s;
    assert(s.isNull);
    s = S(6);
    assert(s == S(6));
    assert(s != S(0));
    assert(s.get != S(0));
    s.x = 9190;
    assert(s.x == 9190);
    s.nullify();
    assertThrown!Throwable(s.x = 9441);
}
unittest
{
    // Ensure Optional can be used in pure/nothrow/@safe environment.
    function() pure nothrow @safe
    {
        Optional!int n;
        assert(n.isNull);
        n = 4;
        assert(!n.isNull);
        assert(n == 4);
        n.nullify();
        assert(n.isNull);
    }();
}
unittest
{
    // Ensure Optional can be used when the value is not pure/nothrow/@safe
    static struct S
    {
        int x;
        this(this) @system {}
    }

    Optional!S s;
    assert(s.isNull);
    s = S(5);
    assert(!s.isNull);
    assert(s.x == 5);
    s.nullify();
    assert(s.isNull);
}
unittest
{
    // Bugzilla 9404
    alias N = Optional!int;

    void foo(N a)
    {
        N b;
        b = a; // `N b = a;` works fine
    }
    N n;
    foo(n);
}
unittest
{
    //Check Optional immutable is constructable
    {
        auto a1 = Optional!(immutable int)();
        auto a2 = Optional!(immutable int)(1);
        auto i = a2.get;
    }
    //Check immutable Optional is constructable
    {
        auto a1 = immutable (Optional!int)();
        auto a2 = immutable (Optional!int)(1);
        auto i = a2.get;
    }
}
unittest
{
    alias NInt   = Optional!int;

    //Construct tests
    {
        //from other Optional null
        NInt a1;
        NInt b1 = a1;
        assert(b1.isNull);

        //from other Optional non-null
        NInt a2 = NInt(1);
        NInt b2 = a2;
        assert(b2 == 1);

        //Construct from similar Optional
        auto a3 = immutable(NInt)();
        NInt b3 = a3;
        assert(b3.isNull);
    }

    //Assign tests
    {
        //from other Optional null
        NInt a1;
        NInt b1;
        b1 = a1;
        assert(b1.isNull);

        //from other Optional non-null
        NInt a2 = NInt(1);
        NInt b2;
        b2 = a2;
        assert(b2 == 1);

        //Construct from similar Optional
        auto a3 = immutable(NInt)();
        NInt b3 = a3;
        b3 = a3;
        assert(b3.isNull);
    }
}
unittest
{
    import std.typetuple;
    //Check Optional is nicelly embedable in a struct
    static struct S1
    {
        Optional!int ni;
    }
    static struct S2 //inspired from 9404
    {
        Optional!int ni;
        this(S2 other)
        {
            ni = other.ni;
        }
        void opAssign(S2 other)
        {
            ni = other.ni;
        }
    }
    foreach (S; TypeTuple!(S1, S2))
    {
        S a;
        S b = a;
        S c;
        c = a;
    }
}
