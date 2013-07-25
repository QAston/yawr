module protocol.packet;

import std.array;
import std.typecons;
import std.traits;

import util.stream;

import protocol.memory_stream;
import protocol.opcode;
import protocol.session;

import wowdefs.wow_version;


class Packet(bool input)
{
    enum isInput = input;
    enum isOutput = !input;

    Opcode opcode;

    /+
        Prarams:
            data - for output packets must be capable of holding all the data, for inputs must have exact size
    +/ 
    this(ubyte[] data, uint opcode, Session session)
    {
        this.data = new BitMemoryStream(data, isOutput);
        // invalid opcode values will be still stored in this.opcode
        this.opcode = cast(Opcode)opcode;
        this.session = session;
    }

    BitMemoryStream data;
    Session session;


    string toHex()
    {
        return data.toHex();
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
    void valCount(COUNTER_TYPE, alias Format = identity, T: U[], U)(ref T value) if (isIntegral!COUNTER_TYPE && isDynamicArray!T)
    {
        static if (isInput)
        {
            if (value !is null)
            {
                throw new PacketException("Trying to read valCount of array which already has valCount (length) set");
            }
            else
            {
                value = new U[cast(size_t)(Format.read!(COUNTER_TYPE)(this))];
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

    /+
     + Reads/Writes a given array
     + Works only on types on which val works
     +/
    void valArray(alias Format = identity, T: U[], U)(ref T value)
    {
        foreach(ref c; value)
        {
            val!(Format)(c);
        }
    }


    /*void valTail(alias Format = identity, T: U[], U)(ref T value, int delegate(ref uint) dg)
    {

        int opApply() 
        {
            int result = 0; for (int i = 0; i < array.length; i++) { result = dg(array[i]); if (result) break; } return result; }
    }*/
    
    /+
     + Reads/Writes a bit of a given structure
     + Doesn't work on types with indirections
     +/
    void valBit(alias Format = identity, T)(ref T value, size_t index)
    {
        import std.bitmanip;
        static assert(!hasIndirections!T, "Cannot interfere with bits of referenced types");
        auto bits = BitArray();
        void[] data = (&value)[0..T.sizeof];
        bits.init(cast(void[])data, T.sizeof);
        Bit bit;
        if (isInput)
        {
            val!(Format)(bit);
            bits[index] = bit;
        }
        else
        {
            bit = bits[index];
            val!(Format)(bit);
        }
    }
    
    /+
     + On read writes a negated bit to given bit of the given structure if bit was set to 1 in the structure
     + On write writes 0 which is neutral to read operation
     +/
    void valBitXor(alias Format = as!ubyte, T)(ref T value, size_t index)
    {
        import std.bitmanip;
        static assert(!hasIndirections!T, "Cannot interfere with bits of referenced types");
        auto bits = BitArray();
        void[] data = (&value)[0..T.sizeof];
        bits.init(cast(void[])data, T.sizeof);
        Bit bit;
        if (isInput)
        {
            if (bits[index])
            {
                val!(Format)(bit);
                bits[index] = !bit;
            }
        }
        else
        {
            if (bits[index])
            {
                // write neutral zero on send - we don't need to fuck with client the way blizz does
                bit = false;
                val!(Format)(bit);
            }
        }
    }
    
    /+
     + Reads/Writes a value which is not part of packet structure
     + Used mostly for unknown fields
     +/
    T skip(T, alias Format = identity)(T t = T.init)
    {
        val!Format(t);
        return t;
    }

    /+
     + Reads/Writes compressed data from inside del to a packet
     + Format: [optional compressed size][decompressed size][compressed data]
     + Params: 
     +  - DEFLATE_STREAM - packet is part of deflate stream
     +  - WITH_SIZE - write/read compressed size of data
     +/
    void deflateBlock(bool DEFLATE_STREAM, bool WITH_SIZE = true)(void delegate() del)
    {
        static if (isInput)
        {
            static if (WITH_SIZE)
            {
                uint compressedSize;
                val(compressedSize);
                compressedSize -= 4;
            }

            uint uncompressedSize;
            val(uncompressedSize);

            static if (WITH_SIZE)
                auto compressedData = data.sreadBytes(cast(size_t)compressedSize);
            else
                auto compressedData = data.sreadBytes(cast(size_t)(data.size - data.tell));

            import util.zlib;
            static if (wowVersion >= WowVersion.V4_3_0_15005 && DEFLATE_STREAM)
                 const(void)[] readBuff = session.uncompressStream.uncompress(cast(const(void)[])compressedData, uncompressedSize);
            else
                const(void)[] readBuff = uncompress(cast(void[])compressedData, uncompressedSize);

            auto oldStream = this.data;

            this.data = new BitMemoryStream(cast(ubyte[])(readBuff.dup), isOutput);

            del();

            if (data.tell != data.size)
                throw new PacketException("Decompressed data was not fully read");

            this.data = oldStream;
        }
        else
        {
            auto oldPos = data.tell;
            del();
            auto newPos = data.tell;
            uint uncompressedSize = cast(uint)(newPos - oldPos);
            data.seek(oldPos);

            auto uncompressedData = cast(const(void)[])data.sreadBytes(uncompressedSize);

            import util.zlib;
            static if (wowVersion >= WowVersion.V4_3_0_15005 && DEFLATE_STREAM)
            {
                const(void)[] compressedBuff = session.compressStream.compress(uncompressedData);
                compressedBuff~= session.compressStream.flush(Z_SYNC_FLUSH);
            }
            else
                const(void)[] compressedBuff = compress(uncompressedData);

            data.seek(oldPos);
            static if (WITH_SIZE)
            {
                uint compressedSize = cast(uint)compressedBuff.length + 4;
                val(compressedSize);
            }
            val(uncompressedSize);

            data.write(cast(ubyte[])compressedBuff);
        }
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

/+
 + Reads/Writes data as bits of given integral type, BITS(number of bits) must be less than bits in type
 +/
template asBits(byte BITS)
{
    import std.conv;
    import std.bitmanip;

    void write(VAL)(Packet!false p, auto ref VAL val) if (isIntegral!VAL)
    {
        // not equal because of signed problems
        static assert(VAL.sizeof * 8 > BITS);
        for (byte i = BITS - 1; i >= 0; --i)
            p.data.writeBit((val & (1 << i)) != 0);
    }
    VAL read(VAL)(Packet!true p)  if (isIntegral!VAL)
    {
        // not equal because of signed problems
        static assert(VAL.sizeof * 8 > BITS);

        static if (is(VAL BASE == enum))
        {
            BASE value = 0;
        }
        else 
        {
            VAL value = 0;
        }
        for (byte i = BITS - 1; i >= 0; --i)
            if (p.data.readBit())
                value |= (1 << i);

        return cast(VAL)value;
    }
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

template as(T)
{
    import std.conv;
    
    void write(VAL)(Packet!false p, auto ref VAL val)
    {
        identity.write(p, val.to!T);
    }
    VAL read(VAL)(Packet!true p)
    {
        return identity.read!T(p).to!VAL;
    }
}

static struct identity
{
    import util.stream;
    
    static void write(VAL)(Packet!false p, auto ref VAL val)
    {
        static if (is (typeof(p.data.swrite!VAL(val))== void))
            p.data.swrite!VAL(val);
        else static if (is (VAL == Bit))
            p.data.writeBit(val);
        else static if (is (typeof(val.handle(p)) == void))
            val.handle(p);
        else
        {
            static if (!is(typeof(VAL) == VAL))
            {
                VAL a;
                a.handle(p);
            }
            static assert(false);
        }
    }

    static VAL read(VAL)(Packet!true p)
    {
        static if (is (typeof(p.data.sread!VAL())== VAL))
            return p.data.sread!VAL();
        else static if (is (VAL == Bit))
            return Bit(p.data.readBit());
        else static if (is (typeof(VAL.init.handle(p)) == void))
        {
            auto val = VAL.init;
            val.handle(p);
            return val;
        }
        else
        {
            static if (!is(typeof(VAL) == VAL))
            {
                VAL a;
                a.handle(p);
            }
            static assert(false);
        }
    }
}

static struct asCString
{
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

unittest {
    import util.test;
    mixin (test!("packetparser"));

    ubyte buffer[] = new ubyte[600];
    void valTest(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0, new Session());
        output.val!(Format)(value);
        auto input = new Packet!true(buffer, 0, new Session());
        T readValue;
        input.val!(Format)(readValue);
        assert(value == readValue);
    }

    valTest!int(7);
    valTest!uint(10u);
    valTest!ubyte(10u);
    valTest!byte(-20);
    valTest!float(7);
    valTest!double(14);
    valTest!Opcode(Opcode.CMSG_CAST_SPELL);

    valTest!(uint, as!(ubyte))(220);
    import std.exception;
    assertThrown!(Throwable)(valTest!(uint, as!(ubyte))(99999));


    void valTestNullable(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0, new Session());
        if (output.valIs!(Format)(value))
            output.val!(Format)(value);
        auto input = new Packet!true(buffer, 0, new Session());
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
        auto output = new Packet!false(buffer, 0, new Session());
        if (output.valIs!(Format)(value))
            output.val!(Format)(value);
        auto input = new Packet!true(buffer, 0, new Session());
        T readValue;
        input.val!(Format)(readValue);
    }

    void valTestNullableError2(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0, new Session());
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
        auto output = new Packet!false(buffer, 0, new Session());
        output.valCount!(COUNTER_TYPE, Format)(value);
        foreach(ref el; value)
        {
            output.val!(Format)(el);
        }
        auto input = new Packet!true(buffer, 0, new Session());
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

    {

        enum A {
            a = 0,
            b = 1,
            c = 2,
        }
        mixin (test!("packetparser - asBits"));

        valTest!(uint, asBits!1)(1);
        valTest!(uint, asBits!1)(0);
        valTest!(uint, asBits!4)(15);
        assertThrown!(Throwable)(valTest!(uint, asBits!3)(15));

        valTest!(A, asBits!4)(A.a);
    }

    void valTestDeflate(bool STREAM, bool WRITE_SIZE)()
    {
        struct Addon {
            string name;
            bool enabled;
            int crc;
            uint unknown;
        }

        auto addon = Addon("asd", true, 123, 5);
        size_t size;

        {
            auto output = new Packet!false(buffer, 0, new Session());
            output.deflateBlock!(STREAM, WRITE_SIZE)((){
                output.val!(asCString)(addon.name);
                output.val(addon.enabled);
                output.val(addon.crc);
                output.val(addon.unknown);
            });
            writeln(output.data.toHex());
            size = cast(size_t)output.data.tell;
        }

        Addon readValue;
        {
            auto input = new Packet!true(buffer[0..size], 0, new Session());
            input.deflateBlock!(STREAM, WRITE_SIZE)((){
                input.val!(asCString)(readValue.name);
                input.val(readValue.enabled);
                input.val(readValue.crc);
                input.val(readValue.unknown);
            });
        }
        assert(addon == readValue);
    }

    {
        mixin (test!("packetparser - deflateBlock"));

        valTestDeflate!(false, false)();
        valTestDeflate!(false, true)();
        
        valTestDeflate!(true, true)();
        valTestDeflate!(true, false)();
    }

    void valTestBit(T, alias Format = identity)(T value)
    {
        auto output = new Packet!false(buffer, 0, new Session());
        foreach(i;0..T.sizeof*8)
        {
            output.valBit!(Format)(value, i);
        }
        auto input = new Packet!true(buffer, 0, new Session());
        T readValue;
        foreach(i;0..T.sizeof*8)
        {
            input.valBit!(Format)(readValue, i);
        }
        assert(value == readValue);
    }

    {
        mixin (test!("packetparser - valBit"));

        
        struct TestS2 {
            uint a;
        }

        auto s = TestS2(68);

        
        valTestBit!(ulong)(78542324);
        valTestBit!(TestS2)(s);
    }
}