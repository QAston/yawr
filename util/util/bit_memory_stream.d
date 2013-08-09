module util.bit_memory_stream;

import std.exception;

import vibe.stream.memory;
import vibe.core.stream;

import util.stream;

import vibe.core.stream;

/+
 + RandomAccess stream interface extended with bit-wise reads/writes
 + Assumes that flushes for bit operations are not neccesary
 +/
interface RandomAccessBitStream : RandomAccessStream, InputBitStream {

    /+
    + Writes single bit to the stream.
    + Byte-wise functions will assume full byte was written here for less than 8 calls made in a row
    +/
    void writeBit(bool bit);
}

/+
 + Input stream interface extended with bit-wise reads
 +/
interface InputBitStream : InputStream {
    /+
    + Reads single bit from the stream
    + Byte-wise functions will assume full byte was read here for less than 8 calls made in a row
    +/
    bool readBit();
}

/+
 + An utility class which allows reading and writing to a memory stream in single bits
 + Based on Memory stream from vibe.d library
 +/
class BitMemoryStream : RandomAccessBitStream {

    private ubyte[] dataBuffer;

    mixin BitStreamBase!(MemoryStream);
    mixin BitStreamInput;
    mixin BitStreamOutput;
    /+
     + Args:
     +   dataBuffer - buffer used by backing stream, can be larget than dataSize and used when resize is called
     +/
    this(ubyte[] dataBuffer, bool writable = true, size_t initialSize = size_t.max)
    {
        this.dataBuffer = dataBuffer;
        this.data = new MemoryStream(dataBuffer, writable, initialSize);
    }

    @property ulong size() const nothrow { return data.size(); }
    @property bool readable() const nothrow { return data.readable(); }
    @property bool writable() const nothrow { return data.writable(); }

    ulong tell() nothrow { return data.tell(); }

    ubyte[] getData()
    {
        return dataBuffer[0..cast(size_t)size()];
    }

    /// Changes position in the stream. Resets in-byte position for bit reads
    void seek(ulong offset)
    {
        flushBits();
        data.seek(offset);
    }
}

/// Wraps an InputStream class and provides bitwise access
class InputBitStreamWrapper(STREAM : InputStream) : InputBitStream
{
    this(STREAM stream)
    {
        this.data = stream;
    }
    mixin BitStreamBase!(STREAM);
    mixin BitStreamInput;
}

mixin template BitStreamBase(STREAM)
{
    private {
        STREAM data;
        ubyte bitBuffer; // buffer for streaming in bits
        ubyte bitBufferPos;
    }
    private void flushBits()
    {
        bitBuffer = 0;
        bitBufferPos = 0;
    }
}

mixin template BitStreamInput() {
    /+
    + Reads bytes from stream
    + Aligned to single byte in memory - if readBit was used call will skip remaining part of current byte
    +/
    void read(ubyte[] dst)
    {
        flushBits();
        data.read(dst);
    }

    /+
    + Reads single bit from the stream
    +/
    bool readBit()
    {
        if (bitBufferPos == 0)
            bitBuffer = data.sread!ubyte;

        auto val = ((bitBuffer >>> (7 - bitBufferPos)) & 1) != 0;
        bitBufferPos++;
        if (bitBufferPos == 8)
            flushBits();
        return val;
    }

    ///
    const(ubyte)[] peek() { return data.peek(); }
    @property bool empty() { return data.empty(); }
    @property ulong leastSize() { return data.leastSize(); }
    @property bool dataAvailableForRead() { return data.dataAvailableForRead; }
}

mixin template BitStreamOutput()
{
    /+
    + Writes bytes to stream
    + Aligned to single byte in memory - if writeBit was used call will skip remaining part of current byte and write next ones
    +/
    void write(in ubyte[] bytes, bool do_flush = true)
    {
        flushBits();
        data.write(bytes, do_flush);
    }

    /+
    + Writes single bit to the stream.
    +/
    void writeBit(bool bit)
    {
        if (bitBufferPos != 0)
            data.seek(data.tell-1);
        bitBuffer |= (bit ? 1 : 0) << (7 - bitBufferPos);
        data.swrite!ubyte(bitBuffer);

        ++bitBufferPos;

        if (bitBufferPos > 7)
            flushBits();
    }

    @property size_t capacity() const nothrow { return data.capacity(); }

    void flush() {data.flush();}
    void finalize() {data.finalize();}
    void write(InputStream stream, ulong nbytes = 0, bool do_flush = true) { writeDefault(stream, nbytes, do_flush); }
}

unittest {
    import util.test;
    test!("BitMemoryStream");
    ubyte buffer[] = new ubyte[20];
    BitMemoryStream stream = new BitMemoryStream(buffer);

    stream.writeBit(false);
    stream.writeBit(true);
    assert(stream.tell == 1);
    stream.swrite!byte(6);
    assert(stream.tell == 2);
    stream.writeBit(true);
    stream.writeBit(false);
    stream.writeBit(true);
    assert(stream.tell == 3);
    stream.swrite!byte(20);
    assert(stream.tell == 4);
    stream.writeBit(true);
    assert(stream.tell == 5);
    stream.writeBit(true);
    stream.writeBit(false);
    stream.writeBit(true);
    stream.writeBit(true);
    stream.writeBit(true);
    stream.writeBit(false);
    assert(stream.tell == 5);
    stream.writeBit(false);
    assert(stream.tell == 5);
    stream.writeBit(false);
    assert(stream.tell == 6);
    stream.seek(0);
    assert(stream.readBit == false);
    assert(stream.readBit == true);
    assert(stream.tell == 1);
    assert(stream.sread!byte == 6);
    assert(stream.tell == 2);
    assert(stream.readBit == true);
    assert(stream.tell == 3);
    assert(stream.readBit == false);
    assert(stream.readBit == true);
    assert(stream.sread!byte == 20);
    assert(stream.readBit == true);
    assert(stream.readBit == true);
    assert(stream.readBit == false);
    assert(stream.readBit == true);
    assert(stream.readBit == true);
    assert(stream.readBit == true);
    assert(stream.readBit == false);
    assert(stream.readBit == false);
}