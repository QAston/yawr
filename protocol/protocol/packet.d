module protocol.packet;

import vibe.stream.memory;
import vibe.core.stream;

import util.stream;

import protocol.opcode;
import std.array;

import std.typecons;

class Packet(bool input)
{
    enum isInput = input;
    enum isOutput = !input;

    MemoryStream data;
    Opcode opcode;

    /+
        Prarams:
            data - for output packets must be capable of holding all the data, for inputs must have exact size
    +/ 
    this(ubyte[] data, uint opcode)
    {
        this.data = new MemoryStream(data, isOutput);
        // invalid opcode values will be still stored in this.opcode
        this.opcode = cast(Opcode)opcode;
    }

    public string toHex()
    {
        ulong oldpos = data.tell;
        scope(exit)
            data.seek(oldpos);

        import std.ascii, std.format;
        import std.array;

        auto dump = appender!(dchar[]);
        
        dump.put("|-------------------------------------------------|---------------------------------|\n");
        dump.put("| 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F | 0 1 2 3 4 5 6 7 8 9 A B C D E F |\n");
        dump.put("|-------------------------------------------------|---------------------------------|\n");

        for (auto i = 0; i < data.size(); i += 16)
        {
            auto text = appender!(dchar[]);
            auto hex = appender!(dchar[]);
            text.put("| ");
            hex.put("| ");
            
            for (auto j = 0; j < 16; j++)
            {
                if (j + i < data.size())
                {
                    data.seek(j + i);
                    auto val = data.sread!ubyte;
                    formattedWrite(hex , "%2X ", val);

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
   

    /+
     + Behavior depends on whenever in input or output mode
     + input: Copies data from stream to value
     + output: Copies data from value to stream
     + Parameters:
     + Format - template functions which handles read/write to stream
     +/
    void val(alias Format = identity, T)(ref T value) if (!isNullable!T && isInput /*&& is(typeof(Format.read!T(this)) == T)*/)
    {
        value = Format.read!T(this);
    }
    /// ditto
    void val(alias Format = identity, T)(ref T value) if (!isNullable!T && !isInput /*&& is(typeof(Format.write(this, value)) == void)*/)
    {
        Format.write(this, value);
    }

    /// ditto
    void val(alias Format = identity, T : Nullable!U, U)(ref T value) if (isInput /*&& is(typeof(Format.read!U(this)) == U)*/ )
    {
        if (value.isNull())
            throw new PacketException("Trying to read nullable!val without reading valIs==true before.");
        value = Format.read!U(this);
    }

    /// ditto
    void val(alias Format = identity, T : Nullable!U, U)(ref T value) if (!isInput /*&& is(typeof(Format.write(this, value.get())) == void)*/)
    {
        if (value.isNull())
            throw new PacketException("Trying to write nullable!val while no value set (missing assignment to val somewhere)");
        else
            Format.write(this, value.get());
    }

    /+
    + Behavior depends on whenever in input or output mode
    + input: Reads boolean indicating if Nullable!val is present from stream
    + output: Writes boolean indicating if Nullable!val is present to stream
    + Parameters:
    + Format - template functions which handles read/write to stream
    +/
    bool valIs(alias Format = identity, T: Nullable!U, U)(ref T value)
    {
        static if (isInput)
        {
            if (Format.read!bool(this) == true)
            {
                value = U.init;
                return true;
            }
            return false;
        }
        else
        {
            Format.write(this, !value.isNull);
            return !value.isNull();
        }
    }
    
    /+
     + Behavior depends on whenever in input or output mode
     + input: Copies data from stream to value's length property
     + output: Copies value's length property from value to stream
     + Parameters:
     + Format - template functions which handles read/write to stream
     +/
    void valCount(COUNTER_TYPE = ubyte, alias Format = identity, T: U[], U)(ref T value) if (isIntegral!COUNTER_TYPE && isDynamicArray!T)
    {
        static if (isInput)
        {
            if (value !is null)
            {
                throw new PacketException("Trying to read valCount of array which already has valCount (length) set");
            }
            else
            {
                value = new U[cast(size_t)Format.read!COUNTER_TYPE(this)];
            }
        }
        else
        {
            if (value is null)
            {
                throw new PacketException("Trying to write null dynamic array, if intended please write zero length array instead");
            }
            if (COUNTER_TYPE.max < value.length)
                throw new PacketException("Using too small counter type for length of given array, trim the array or change COUNTER_TYPE");
            auto cntr =cast(COUNTER_TYPE)value.length;
            Format.write(this, cntr);
        }
    }

    /*void valTail(alias Format = identity, T: U[], U)(ref T value, int delegate(ref uint) dg)
    {

        int opApply() 
        {
            int result = 0; for (int i = 0; i < array.length; i++) { result = dg(array[i]); if (result) break; } return result; }
    }*/
    
    void valBit(alias Format = identity, T)(ref T value, size_t index)
    {
        
    }
    
    void valXor(alias Format = identity, T)(ref T value, size_t index)
    {
        
    }
    
    /+
     + 
     + 
     +/
    void skip(T, alias Format = identity)()
    {
        T t;
        val!Format(t);
    }
}

class PacketException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

template isNullable(T: Nullable!U, U)
{
    enum isNullable = true;
}

template isNullable(T)
{
    enum isNullable = false;
}

struct Handler(Opcode op)
{
    enum opcode = op;
}

// packet read/write primitives
template as(T)
{
    import vibe.core.stream;
    import util.stream;
    import std.conv;
    
    void write(VAL)(Packet!false p, auto ref VAL val) if (is (typeof(identity.write(p, val.to!T)) == void))
    {
        identity.write(p, val.to!T);
    }
    VAL read(VAL)(Packet!true p) if (is (typeof(identity.read!T(p)) == T))
    {
        return identity.read!T(p).to!VAL;
    }
}

static struct identity
{
    import vibe.core.stream;
    import util.stream;
    
    static void write(VAL)(Packet!false p, auto ref VAL val) if (is (typeof(p.data.swrite!VAL(val))== void))
    {
        p.data.swrite!VAL(val);
    }
    static void write(VAL)(Packet!false p, auto ref VAL val) if (is (typeof(val.handle(p)) == void))
    {
        val.handle(p);
    }
    static VAL read(VAL)(Packet!true p) if (is (typeof(p.data.sread!VAL())== VAL))
    {
        return p.data.sread!VAL();
    }
    static VAL read(VAL)(Packet!true p) if (is (typeof(VAL.init.handle(p)) == void))
    {
        auto val = VAL.init;
        val.handle(p);
        return val;
    }
}

static struct asCString
{
    import vibe.core.stream;
    import util.stream;
    import std.conv;
    import std.traits;

    static void write(VAL)(Packet!false p, ref VAL val) if (isSomeString!VAL)
    {
        foreach(ref c; val)
        {
            p.data.swrite!char(c);
        }
        p.data.swrite!char('\0');
    }
    static VAL read(VAL)(Packet!true p) if (isSomeString!VAL)
    {
        auto cstr = appender!(char[]);
       
        while (!p.data.empty())  // CDataStore::GetCString checks for empty too
        {
            auto c = p.data.sread!char();
            if (c == '\0')
            {
                break;
            }
            cstr.put(c);
        }

        return cstr.data.to!VAL();
    }
}

static struct asArray(T)
{
    import vibe.core.stream;
    import util.stream;
    import std.conv;
    import std.array;

    static void write(VAL)(Packet!false p, ref VAL val)
    {
        foreach(ref c; val)
        {
            p.data.swrite!T(c);
        }
    }
    static VAL read(VAL)(Packet!true p)
    {
        auto cstr = appender!(T[]);
        foreach(ref c; val)
        {
            cstr.put(p.data.sread!T(c));
        }

        return cstr.data.to!VAL();
    }
}

unittest {
    import util.test;
    mixin (test!("packetparser"));

    ubyte buffer[] = new ubyte[600];
    void valTest(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0);
        output.val!(Format)(value);
        auto input = new Packet!true(buffer, 0);
        T readValue;
        input.val!(Format)(readValue);
        assert(value == readValue);
    }

    valTest!int(7);
    valTest!uint(10u);
    valTest!ubyte(10u);
    valTest!byte(-20);
    valTest!Opcode(Opcode.CMSG_CAST_SPELL);

    valTest!(uint, as!(ubyte))(220);
    import std.exception;
    assertThrown!(Throwable)(valTest!(uint, as!(ubyte))(99999));


    void valTestNullable(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0);
        if (output.valIs!(Format)(value))
            output.val!(Format)(value);
        auto input = new Packet!true(buffer, 0);
        T readValue;
        if (input.valIs!(Format)(readValue))
            input.val!(Format)(readValue);
        if (value.isNull())
            assert(readValue.isNull());
        else
            assert(value == readValue);
    }

    void valTestNullableError1(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0);
        if (output.valIs!(Format)(value))
            output.val!(Format)(value);
        auto input = new Packet!true(buffer, 0);
        T readValue;
        input.val!(Format)(readValue);
    }

    void valTestNullableError2(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0);
        output.val!(Format)(value);
    }

    {
        mixin (test!("packetparser - nullable"));
        Nullable!uint a = 78;
        valTestNullable(a);
        Nullable!uint b;
        valTestNullable(b);

        assertThrown!(PacketException)(valTestNullableError1(a));
        assertThrown!(PacketException)(valTestNullableError2(b));
    }
    

    void valTestDynArray(COUNTER_TYPE = byte, alias Format = identity, T)(T value)
    {
        auto output = new Packet!false(buffer, 0);
        output.valCount!(COUNTER_TYPE, Format)(value);
        foreach(ref el; value)
        {
            output.val!(Format)(el);
        }
        auto input = new Packet!true(buffer, 0);
        T readVal;
        input.valCount!(COUNTER_TYPE, Format)(readVal);
        foreach(ref el; readVal)
        {
            input.val!(Format)(el);
        }
        assert(readVal == value);
    }
    
    {
        mixin (test!("packetparser - nullable"));
        ubyte[] a = new ubyte[60];
        foreach(i, el; a)
        {
            el = cast(ubyte)i;
        }
        valTestDynArray(a);
        uint[] b = new uint[20];
        foreach(i, el; b)
        {
            el = i;
        }
        valTestDynArray(b);

        ulong[] c;
        ubyte[] d = new ubyte[300];

        assertThrown!(PacketException)(valTestDynArray(c));
        assertThrown!(PacketException)(valTestDynArray!ubyte(d));
    }

    {
        mixin (test!("packetparser - asCString"));

        string a = "teststring";
        valTest!(string, asCString)(a);
    }

    {
        struct TestS {
            uint a;
            bool b;
            void handle(bool INPUT)(Packet!INPUT p)
            {
                p.val(a);
                p.val(b);
            }
        }

        mixin (test!("packetparser - substructure"));

        auto s = TestS(10, true);
        valTest(s);
    }

}