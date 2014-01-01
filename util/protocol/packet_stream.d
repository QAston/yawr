/+
 + This module provides PacketStream class and related types
 +/
module util.protocol.packet_stream;

import std.array;
import std.typecons;
import std.traits;

import util.stream;
import util.binary;
import util.typecons;

import util.bit_memory_stream;
import util.algorithm;

import vibe.stream.memory;
import vibe.stream.counting;
import vibe.stream.operations;

/+
 + An utility class which allows writing and reading data from a memory stream in a neat way
 + Neat thing is that user can specify a single function which can handle both reading and writing to the stream using the same code
 + Significantly reduces duplication, makes testing easier and encourages reuse of packet handlers
 + val* functions here mimic the way blizzard is sending packet data, some of them are made specially for patterns found in those
 +/
final class PacketStream(bool input)
{
    enum isInput = input;
    enum isOutput = !input;

    /+
     + Params:
     +      input - true for input stream(allows reading), false for output streams
     + Args:
     +      data - for output packets must be capable of holding all the data, for inputs must have exact size
     +      compress/decompress - delegates responsible of handling stream compressions when requested by deflateBlock function
     +/ 
    static if (input == true)
    {
        this(ubyte[] data, void[] delegate(bool,void[], size_t) decompress) 
        {
            this.data = new InputBitStreamWrapper(new MemoryStream(data, false));
            this.decompress = decompress;
        }
        this(InputBitStream data, void[] delegate(bool,void[], size_t) decompress) 
        {
            this.data = data;
            this.decompress = decompress;
        }
        private void[] delegate(bool,void[], size_t) decompress;
        InputBitStream data;
    }
    else
    {
        this(void[] delegate(bool,void[]) compress)
        {
            this.data = new MemoryOutputBitStream();
            this.compress = compress;
        }
        private void[] delegate(bool,void[]) compress;
        MemoryOutputBitStream data;
    }

    static if(isOutput)
    {
        /+
         + Returns data written so far to the stream
         +/
        ubyte[] getData()
        {
            return data.getData();
        }

        /+
        + returns hex dump representation of memory stream
        +/
        string toHex()
        {
            import util.struct_printer;
            return data.getData().toHex();
        }
    }

    /+
     + input: Copies data from stream to value
     + output: Copies data from value to stream
     + Params:
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    void val(alias Format = identity, T)(ref T value) if (!isMarkedOpt!T && !isOpt!T && isInput)
    {
        value = Format.read!T(this);
    }
    /// ditto
    void val(alias Format = identity, T)(ref T value) if (!isMarkedOpt!T && !isOpt!T && !isInput)
    {
        Format.write(this, value);
    }

    /// ditto
    void val(alias Format = identity, T : MarkedOpt!U, U)(ref T value) if (isInput)
    {
        if (value.isNull())
            throw new PacketStreamException("Trying to read MarkedOpt!val without reading valMark==true before.");
        value = Format.read!U(this);
    }

    /// ditto
    void val(alias Format = identity, T : MarkedOpt!U, U)(ref T value) if (!isInput)
    {
        if (value.isNull())
            throw new PacketStreamException("Trying to write MarkedOpt!val while no value set (missing assignment to val somewhere)");
        else
            Format.write(this, value.get());
    }

    /// ditto
    void val(alias Format = identity, T : Opt!U, U)(ref T value) if (isInput)
    {
        value = Format.read!U(this);
    }

    /// ditto
    void val(alias Format = identity, T : Opt!U, U)(ref T value) if (!isInput)
    {
        if (value.isNull())
            throw new PacketStreamException("Trying to write Opt!val while no value set (missing assignment somewhere)");
        else
            Format.write(this, value.get());
    }

    /+
     + input: Reads boolean indicating if MarkedOpt!val is present from stream
     + output: Writes boolean indicating if MarkedOpt!val is present to stream
     + Params:
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    bool valMark(alias Format = identity, T: MarkedOpt!U, U)(ref T value)
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
     + input: Copies data from stream to value's length property
     + output: Copies value's length property from value to stream
     + Params:
     +     COUNTER_TYPE - integer type for binary representation in stream
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    void valCount(COUNTER_TYPE, alias Format = identity, T: U[], U)(ref T value) if (isIntegral!COUNTER_TYPE && isDynamicArray!T)
    {
        import util.typecons : emptyArray;
        static if (isInput)
        {
            if (value !is null)
            {
                throw new PacketStreamException("Trying to read valCount of array which already has valCount (length) set");
            }
            else
            {
                auto size = cast(size_t)(Format.read!(COUNTER_TYPE)(this));
                if (size == 0)
                    value = emptyArray!U;
                else
                    value = new U[size];
                assert(value !is null);
            }
        }
        else
        {
            if (value is null)
            {
                throw new PacketStreamException("Trying to write null dynamic array, if intended please write zero length array instead");
            }
            if (COUNTER_TYPE.max < value.length)
                throw new PacketStreamException("Using too small counter type for length of given array, trim the array or change COUNTER_TYPE");
            auto cntr =cast(COUNTER_TYPE)value.length;
            Format.write(this, cntr);
        }
    }

    /+
     + Reads/Writes a given array
     + Works only on types on which val works
     + Params:
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    void valArray(alias Format = identity, T: U[], U)(ref T value)
    {
        foreach(ref c; value)
        {
            val!(Format)(c);
        }
    }

    /+
     + A sequence of Reads/Writes into an array elements with given indexes
     + Params:
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    void valArraySeq(alias Format = identity, T: U[], U)(ref T value, int[] indexes...)
    in {
        assert(indexes.length <= value.length);
        assert(elementsUnique(indexes));
    }
    body {
        foreach(i; indexes)
        {
            val!(Format)(value[i]);
        }
    }

    /+
     + Writes/Reads a bit[index] of a given structure
     + Params:
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    void valBit(alias Format = identity, T)(ref T value, size_t index)
    {
        auto bits = asBitArray(value);

        Bit bit;
        static if (isInput)
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
     + Writes/Reads bit 1 to stream if byte of given index was present in value
     + Used as primitive compression method
     +/
    void valPackMarkByte(alias Format = identity, T)(ref T value, size_t index)
    {
        auto bytes = asByteArray(value);
        static if (isInput)
        {
            Bit notZero;
            val!(Format)(notZero);
            bytes[index] = notZero;
            assert(bytes[index] == 0 || bytes[index] == 1); 
        }
        else
        {
            Bit notZero = bytes[index] != 0;
            val!(Format)(notZero);
        }
    }

    /+
     + A sequence of valPackMarkByte calls with given indexes
     +/
    void valPackMarkByteSeq(alias Format = identity, T)(ref T value, int[] indexes... )
    in {
        assert(indexes.length <= T.sizeof);
        assert(elementsUnique(indexes));
    }
    body {
        foreach(i; indexes)
        {
            valPackMarkByte(value, cast(size_t)i);
        }
    }
    
    /+
     + Writes/Reads byte^1 of given index to stream if the byte has nonzero value
     + Used as primitive compression method
     +/
    void valPackByte(alias Format = identity, T)(ref T value, size_t index)
    {
        auto bytes = asByteArray(value);

        static if (isInput)
        {
            if (bytes[index])
            {
                assert(bytes[index] == 1, "Invalid value for valPackByte - most likely call is done twice on the same byte");
                ubyte b;
                val!(Format)(b);
                bytes[index] ^= b;
            }
        }
        else
        {
            if (bytes[index])
            {
                ubyte b = bytes[index]^1;
                val!(Format)(b);
            }
        }
    }

    /+
     + A sequence of valPackByte calls with given indexes
     +/
    void valPackByteSeq(alias Format = identity, T)(ref T value, int[] indexes... )
    in {
        assert(indexes.length <= T.sizeof);
        assert(elementsUnique(indexes));
    }
    body {
        foreach(i; indexes)
        {
            valPackByte(value, cast(size_t)i);
        }
    }

    
    /+
     + Reads/Writes a value which is not part of packet data structure
     + Used mostly for unknown fields
     + Params:
     +     Format - template functions which handle read/write to stream; allow reading/writing in a non-standard way(ex. asBits)
     +/
    T skip(T, alias Format = identity)(T t = T.init)
    {
        val!Format(t);
        return t;
    }

    /+
     + Specifies a block of data which size will be read/written by valBlockSize function
     + If possible - use valBlockSize(del) shorthand instead - it covers most of cases
     + Args:
     +    blockSize - result of valBlockSize function
     +    del - delegate grouping reads/writes of data
     +/
    void block(BLOCK_SIZE_TYPE: BlockSize!(input,SIZE_TYPE, INCLUDE_SIZE), SIZE_TYPE, bool INCLUDE_SIZE)(BLOCK_SIZE_TYPE blockSize, void delegate() del)
    {
        static if (isInput)
        {
            SIZE_TYPE size = blockSize.expectedSize;
            static if (INCLUDE_SIZE)
                size -= SIZE_TYPE.sizeof;

            auto readBuff = data.sreadBytes(size);

            auto oldStream = this.data;
            auto countingStream = new CountingInputStream(new MemoryStream(readBuff, false));
            this.data = new InputBitStreamWrapper(countingStream);
            scope(exit)
                this.data = oldStream;

            del();

            if (countingStream.bytesRead != readBuff.length)
                throw new PacketStreamException("Data block was not fully read");
        }
        else
        {
            auto oldPos = data.getData.length;
            del();
            auto newPos = data.getData.length;
            SIZE_TYPE size = cast(SIZE_TYPE)(newPos - oldPos);

            auto oldStream = this.data;
            this.data = blockSize.stream;
            scope(exit)
                this.data = oldStream;

            auto blockSizeData = this.data.getData;

            static if (INCLUDE_SIZE)
                size += SIZE_TYPE.sizeof;

            //val(size);

            blockSizeData[cast(size_t)blockSize.pos..cast(size_t)blockSize.pos+SIZE_TYPE.sizeof][] = asByteArray(size)[];
        }
    }

    /+
     + Indicates that size of a block of data will be read/written in the place of the call
     + Returns a parameter to block function which specifies block of data, which size will be written/read
     + Should be used in conjuction block function
     + If possible - use valBlockSize(del) shorthand instead - it covers most of cases
     + Params:
     +    SIZE_TYPE - integral type to be used as size
     +    INCLUDE_SIZE - true if block size written/read should include SIZE_TYPE.sizeof
     +/
    BlockSize!(input,SIZE_TYPE, INCLUDE_SIZE) valBlockSize(SIZE_TYPE, bool INCLUDE_SIZE)() if (isIntegral!SIZE_TYPE)
    {
        SIZE_TYPE size;
        auto block = new BlockSize!(input,SIZE_TYPE, INCLUDE_SIZE);
        static if (isInput)
        {
            val(size);
            block.expectedSize = size;
        }
        else
        {
            // save place to write block size to
            block.stream = this.data;
            block.pos = this.data.getData.length;
            // put a placeholder value in the stream
            val(size);
        }
        return block;
    }

    /+
     + Reads/Writes size of a block of data followed by that block
     + Params:
     +    SIZE_TYPE - integral type to be used as size
     +    INCLUDE_SIZE - true if block size written/read should include SIZE_TYPE.sizeof
     +/
    void valBlockSize(SIZE_TYPE, bool INCLUDE_SIZE)(void delegate() del) if (isIntegral!SIZE_TYPE)
    {
        auto blockSize = valBlockSize!(SIZE_TYPE, INCLUDE_SIZE)();
        block(blockSize, del);
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
            {
                auto compressedData = data.readAll();
            }

            void[] readBuff = decompress(DEFLATE_STREAM, compressedData, uncompressedSize);

            auto oldStream = this.data;

            auto countingStream = new CountingInputStream(new MemoryStream(cast(ubyte[])readBuff, false));
            this.data = new InputBitStreamWrapper(countingStream);
            scope(exit)
                this.data = oldStream;

            del();

            if (countingStream.bytesRead != readBuff.length)
                throw new PacketStreamException("Data block was not fully read");
        }
        else
        {
            auto oldStream = this.data;
            this.data = new MemoryOutputBitStream();

            del();

            auto uncompressedData = this.data.getData();
            this.data = oldStream;

            void[] compressedBuff = compress(DEFLATE_STREAM, uncompressedData);

            static if (WITH_SIZE)
            {
                uint compressedSize = cast(uint)compressedBuff.length + 4;
                val(compressedSize);
            }
            uint uncompressedSize = uncompressedData.length;
            val(uncompressedSize);

            data.write(cast(ubyte[])compressedBuff);
        }
    }
}

/// Helper class for block function
class BlockSize(bool INPUT : true, SIZE_TYPE, bool INCLUDE_SIZE)
{
    private SIZE_TYPE expectedSize;
}

/// ditto
class BlockSize(bool INPUT : false, SIZE_TYPE, bool INCLUDE_SIZE)
{
    private {
        MemoryOutputBitStream stream;
        ulong pos;
    }
}

/+
 + Struct which wraps data that is optional part of the packet
 + Used for easier detection of errors by distinguishing optionally set data from default-initialized data
 +/
struct Opt(T)
{
    pure this()(inout T value) inout  // proper signature
    {
        optStruct = value;
    }
    mixin Proxy!optStruct;
    util.typecons.Nullable!T optStruct;
}

/+
 + Struct which wraps data that is optional part of the packet
 + Before using val() on this you need to use valMark() to read/write a bit mark telling if structure is present in packet
 +/
struct MarkedOpt(T)
{
    this(T value)
    {
        optStruct = value;
    }

    mixin Proxy!optStruct;
    util.typecons.Nullable!T optStruct;
}

class PacketStreamException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

template isMarkedOpt(T: MarkedOpt!U, U)
{
    enum isMarkedOpt = true;
}

template isMarkedOpt(T)
{
    enum isMarkedOpt = false;
}

template isOpt(T: Opt!U, U)
{
    enum isOpt = true;
}

template isOpt(T)
{
    enum isOpt = false;
}

/+
 + A Format parameter for val* functions of PacketStream class
 + Reads/Writes data as bits of given integral type, BITS(number of bits) must be less than bits in type
 +/
template asBits(byte BITS)
{
    import std.conv;
    import std.bitmanip;

    void write(VAL, PACKET_STREAM)(PACKET_STREAM p, auto ref VAL val) if (PACKET_STREAM.isOutput && isIntegral!VAL)
    {
        // not equal because of signed problems
        static assert(VAL.sizeof * 8 > BITS);
        for (byte i = BITS - 1; i >= 0; --i)
            p.data.writeBit((val & (1 << i)) != 0);
    }
    VAL read(VAL, PACKET_STREAM)(PACKET_STREAM p) if (PACKET_STREAM.isInput && isIntegral!VAL)
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

/+
 + A Format parameter for val* functions of PacketStream class
 + Reads/Writes string as binary representation of type T
 +/
template as(T)
{
    import std.conv;
    
    void write(VAL, PACKET_STREAM)(PACKET_STREAM p, auto ref VAL val) if (PACKET_STREAM.isOutput)
    {
        identity.write(p, val.to!T);
    }
    VAL read(VAL, PACKET_STREAM)(PACKET_STREAM p) if (PACKET_STREAM.isInput)
    {
        return identity.read!T(p).to!VAL;
    }
}

/+
 + A Format parameter for val* functions of PacketStream class
 + Reads/Writes value as their bin representation
 + Can read structures which define method: void stream(bool INPUT)(PacketStream)
 +/
static struct identity
{
    import util.stream;
    
    static void write(VAL, PACKET_STREAM)(PACKET_STREAM p, auto ref VAL val) if (PACKET_STREAM.isOutput)
    {
        static if (is (typeof(p.data.swrite!VAL(val))== void))
            p.data.swrite!VAL(val);
        else static if (is (VAL == Bit))
            p.data.writeBit(val);
        else static if (is (typeof(val.stream(p)) == void))
            val.stream(p);
        else
        {
            static if (!is(typeof(VAL) == VAL))
            {
                VAL a;
                a.stream(p);
            }
            static assert(false);
        }
    }

    static VAL read(VAL, PACKET_STREAM)(PACKET_STREAM p) if (PACKET_STREAM.isInput)
    {
        static if (is (typeof(p.data.sread!VAL())== VAL))
            return p.data.sread!VAL();
        else static if (is (VAL == Bit))
            return Bit(p.data.readBit());
        else static if (is (typeof(VAL.init.stream(p)) == void))
        {
            auto val = VAL.init;
            val.stream(p);
            return val;
        }
        else
        {
            static if (!is(typeof(VAL) == VAL))
            {
                VAL a;
                a.stream(p);
            }
            static assert(false);
        }
    }
}

/+
 + A Format parameter for val* functions of PacketStream class
 + Reads/Writes string as ASCIIZ
 +/
static struct asCString
{
    import std.conv;
    
    static void write(VAL, PACKET_STREAM)(PACKET_STREAM p, auto ref VAL val) if (PACKET_STREAM.isOutput && isSomeString!VAL)
    {
        foreach(ref c; val)
        {
            p.data.swrite!char(c);
        }
        p.data.swrite!char('\0');
    }
    static VAL read(VAL, PACKET_STREAM)(PACKET_STREAM p) if (PACKET_STREAM.isInput && isSomeString!VAL)
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
    mixin (test!("packet_stream"));

    void valTest(T, alias Format = identity)(T value)
    {
        auto output = new PacketStream!false(null);
        output.val!(Format)(value);
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer, null);
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

    valTest!(uint, as!(ubyte))(220);
    import std.exception;
    assertThrown!(Throwable)(valTest!(uint, as!(ubyte))(99999));


    void valTestMarkedOpt(T, alias Format = identity)(T value)
    {
        auto output = new PacketStream!false(null);
        if (output.valMark!(Format)(value))
            output.val!(Format)(value);
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer, null);
        T readValue;
        if (input.valMark!(Format)(readValue))
            input.val!(Format)(readValue);
        if (value.isNull())
            assert(readValue.isNull());
        else
            assert(value == readValue);
    }

    void valTestMarkedOptError1(T, alias Format = identity)(T value)
    {
        auto output = new PacketStream!false(null);
        if (output.valMark!(Format)(value))
            output.val!(Format)(value);
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer, null);
        T readValue;
        input.val!(Format)(readValue);
    }

    void valTestMarkedOptError2(T, alias Format = identity)(T value)
    {
        auto output = new PacketStream!false(null);
        output.val!(Format)(value);
    }

    {
        mixin (test!("packetstream - MarkedOpt"));
        MarkedOpt!uint a = 78;
        valTestMarkedOpt(a);
        MarkedOpt!uint b;
        valTestMarkedOpt(b);

        assertThrown!(PacketStreamException)(valTestMarkedOptError1(a));
        assertThrown!(PacketStreamException)(valTestMarkedOptError2(b));
    }

    {
        mixin (test!("packetstream - Opt"));
        Opt!uint a = 78;
        valTest(a);
        Opt!uint b;
        assertThrown!(PacketStreamException)(valTest(b));
    }
    

    void valTestDynArray(COUNTER_TYPE = byte, alias Format = identity, T)(T value)
    {
        auto output = new PacketStream!false(null);
        output.valCount!(COUNTER_TYPE, Format)(value);
        foreach(ref el; value)
        {
            output.val!(Format)(el);
        }
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer, null);
        T readVal;
        input.valCount!(COUNTER_TYPE, Format)(readVal);
        foreach(ref el; readVal)
        {
            input.val!(Format)(el);
        }
        assert(readVal == value);
    }
    
    {
        mixin (test!("packetstream - nullable, array"));
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

        assertThrown!(PacketStreamException)(valTestDynArray(c));
        assertThrown!(PacketStreamException)(valTestDynArray!ubyte(d));
    }

    void valArraySeqTest(T, alias Format = identity)(T value, int[]indexes...)
    {
        auto output = new PacketStream!false(null);
        output.valArraySeq!(Format)(value, indexes);
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer, null);
        T readValue;
        input.valArraySeq!(Format)(readValue, indexes);
        foreach(i;indexes)
        {
            assert(value[i] == readValue[i]);
        }
    }

    {
        mixin (test!"packetstream - valArraySeq");
        ubyte[5] a = [0,4,6,7,3];
        valArraySeqTest(a, 0,1,2,3,4);
        valArraySeqTest(a, 3,4,0,1,2);
        valArraySeqTest(a, 4,0,1,2);
        valArraySeqTest(a, 1,2);
    }

    void valPackByteSeqTest(T, alias Format = identity)(T value, int[]markIndexes, int[]byteIndexes)
    {
        auto output = new PacketStream!false(null);
        output.valPackMarkByteSeq!(Format)(value, markIndexes);
        output.valPackByteSeq!(Format)(value, byteIndexes);
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer, null);
        T readValue;
        input.valPackMarkByteSeq!(Format)(readValue, markIndexes);
        input.valPackByteSeq!(Format)(readValue, byteIndexes);

        assert(value == readValue);
    }


    {
        mixin (test!"packetstream - valPackByteSeq tests");
        ulong a= 0x11223344;
        valPackByteSeqTest(a, [6, 1, 5, 2, 7, 0, 3, 4], [5, 3, 1, 4, 6, 0, 7, 2]);
        valPackByteSeqTest(a, [5, 3, 1, 4, 6, 0, 7, 2], [6, 1, 5, 2, 7, 0, 3, 4]);
    }

    {
        mixin (test!("packetstream - asCString"));

        string a = "teststring";
        valTest!(string, asCString)(a);
    }

    {
        struct TestS {
            uint a;
            bool b;
            void stream(PACKET_STREAM)(PACKET_STREAM p)
            {
                p.val(a);
                p.val(b);
            }
        }

        mixin (test!("packetstream - substructure"));

        auto s = TestS(10, true);
        valTest(s);
    }

    {

        enum A {
            a = 0,
            b = 1,
            c = 2,
        }
        mixin (test!("packetstream - asBits"));

        valTest!(uint, asBits!1)(1);
        valTest!(uint, asBits!1)(0);
        valTest!(uint, asBits!4)(15);
        assertThrown!(Throwable)(valTest!(uint, asBits!3)(15));

        valTest!(A, asBits!4)(A.a);
    }


    void valTestBlockSize(SIZE_TYPE, bool INCLUDE_SIZE)()
    {
        struct Addon {
            string name;
            bool enabled;
            int crc;
            uint unknown;
        }

        auto addon = Addon("asd", true, 123, 5);
        ubyte buffer[] = void;

        {
            auto output = new PacketStream!false(null);
            auto blockSize = output.valBlockSize!(SIZE_TYPE, INCLUDE_SIZE)();
            output.val(addon.unknown);
            output.block(blockSize, (){
                output.val!(asCString)(addon.name);
                output.val(addon.enabled);
                output.val(addon.crc);
                
            });
            buffer = output.getData();
        }

        Addon readValue;
        {

            auto input = new PacketStream!true(buffer, null);
            auto blockSize = input.valBlockSize!(SIZE_TYPE, INCLUDE_SIZE)();
            input.val(readValue.unknown);
            input.block(blockSize, (){
                input.val!(asCString)(readValue.name);
                input.val(readValue.enabled);
                input.val(readValue.crc);
            });
        }
        assert(addon == readValue);
    }

    {
        mixin (test!("packetstream - blockSize"));

        valTestBlockSize!(uint, true)();
        valTestBlockSize!(uint, false)();
        valTestBlockSize!(ushort, false)();
        valTestBlockSize!(ushort, true)();
    }

    void valTestDeflate(bool STREAM, bool WRITE_SIZE)()
    {
        import std.zlib;
        struct Addon {
            string name;
            bool enabled;
            int crc;
            uint unknown;
        }

        auto addon = Addon("asd", true, 123, 5);
        ubyte buffer[] = void;

        {
            auto output = new PacketStream!false((bool b, void[] uncompressedData){return compress(uncompressedData).dup;});
            output.deflateBlock!(STREAM, WRITE_SIZE)((){
                output.val!(asCString)(addon.name);
                output.val(addon.enabled);
                output.val(addon.crc);
                output.val(addon.unknown);
            });
            buffer = output.getData();
        }

        Addon readValue;
        {
            auto input = new PacketStream!true(buffer, (bool b, void[] compressedData, size_t uncompressedSize){return uncompress(compressedData, uncompressedSize).dup;});
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
        mixin (test!("packetstream - deflateBlock"));

        valTestDeflate!(false, false)();
        valTestDeflate!(false, true)();
        
        valTestDeflate!(true, true)();
        valTestDeflate!(true, false)();
    }

    void valTestBit(T, alias Format = identity)(T value)
    {
        auto output = new PacketStream!false(null);
        foreach(i;0..T.sizeof*8)
        {
            output.valBit!(Format)(value, i);
        }
        ubyte buffer[] = output.getData();
        auto input = new PacketStream!true(buffer,null);
        T readValue;
        foreach(i;0..T.sizeof*8)
        {
            input.valBit!(Format)(readValue, i);
        }
        assert(value == readValue);
    }

    {
        mixin (test!("packetstream - valBit"));

        
        struct TestS2 {
            uint a;
        }

        auto s = TestS2(68);

        valTestBit!(ulong)(78542324);
        valTestBit!(TestS2)(s);
    }
}