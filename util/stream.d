/+
 + This module provides stream utilities
 +/
module util.stream;

import std.bitmanip;
import std.system;
import std.traits;

/+
 + Returns true for input streams usable by util
 +/
private template isInStream(T) {
    enum isInStream = is (typeof(T.read([0u])) == void);
}

/+
 + Returns true for output streams usable by util
 +/
private template isOutStream(T) {
     enum isOutStream = is (typeof(T.write([0u])) == void);
}

/+
 + Reads Integral/Char/Boolean/FloatingPoint from an INSTREAM
 +/
T sread(T, INSTREAM, Endian endianness = Endian.littleEndian)(INSTREAM s)
{
    ubyte[T.sizeof] array;
    ubyte[] buffer = array[];
    s.read(buffer);
    return buffer.read!(T, endianness)();
}

static assert (bool.sizeof == 1);

/+
 + Reads array of bytes of a given size out of an INSTREAM
 +/
ubyte[] sreadBytes(INSTREAM)(INSTREAM stream, size_t size) if (isInStream!(INSTREAM))
{
    ubyte[] data = new ubyte[size];
    
    stream.read(data);
    return data;
}

/+
 + Writes Integral/Char/Boolean/FloatingPoint to an INSTREAM
 +/
void swrite(T, OUTSTREAM, Endian endianness = Endian.littleEndian)(OUTSTREAM s, T value)
{
    ubyte[T.sizeof] array;
    ubyte[] buffer = array[];
    buffer.write!(T, endianness)(value, 0);
    s.write(buffer);
}

/+
 + generates tests for a given implementation of a inout stream
 + CREATE_STREAM returns a in & out stream
 +/
mixin template tests(alias CREATE_STREAM) if ((isInStream!(ReturnType!(CREATE_STREAM))) && isOutStream!(ReturnType!(CREATE_STREAM)))
{
    import std.traits;
    
    unittest {
        void test(T)(T val)
        {
            auto stream = CREATE_STREAM(T.sizeof);
            stream.swrite!(T, ReturnType!(CREATE_STREAM))(val);
            stream.seek(0);
            assert(stream.sread!(T, ReturnType!(CREATE_STREAM)) == val);
        }

        test!ulong(100000);
        test!long(900);
        test!uint(5);
        test!int(-5);
        test!short(7);
        test!byte(7);
        test!float(1.7);
        test!double(32.6);
        test!bool(true);
    }
}

private {
    class MockStream
    {
        ubyte[] data = null;
        bool begin = true;
        void read(ubyte[] dst)
        {
            assert(data !is null && begin);
            foreach(i, ref el; dst)
            {
                el = data[i];
            }
        }

        void write(in ubyte[] bytes)
        {
            assert(data is null);
            data = bytes[].dup;
            begin = false;
        }

        void seek(size_t pos)
        {
            assert(pos == 0);
            begin = true;
        }
    }

    mixin tests!((size_t size) => new MockStream());
}



