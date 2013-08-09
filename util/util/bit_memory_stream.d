module util.bit_memory_stream;

import std.exception;

import vibe.stream.memory;
import vibe.core.stream;

import util.stream;

import vibe.core.stream;
import vibe.utils.array;
import vibe.utils.memory;

/+
 + RandomAccess stream interface extended with bit-wise reads/writes
 + Assumes that flushes for bit operations are not neccesary
 +/
interface OutputBitStream : OutputStream {

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

class MemoryOutputBitStream : OutputBitStream
{
    MemoryOutputStream stream;
	this(shared(Allocator) alloc = defaultAllocator())
	{
		stream = new MemoryOutputStream(alloc);
	}

    ubyte[] getData()
    {
        return stream.data;
    }
    mixin BitStreamBase;
    mixin BitStreamOutput!(stream);
}

/// Wraps an InputStream class and provides bitwise access
class InputBitStreamWrapper : InputBitStream
{
    InputStream stream;
    this(InputStream stream)
    {
        this.stream = stream;
    }
    mixin BitStreamBase;
    mixin BitStreamInput!(stream);
}

mixin template BitStreamBase()
{
    private {
        ubyte bitBuffer; // buffer for streaming in bits
        ubyte bitBufferPos;
    }
    private void flushBits()
    {
        bitBuffer = 0;
        bitBufferPos = 0;
    }
}

mixin template BitStreamInput(alias data) {
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

mixin template BitStreamOutput(alias data)
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
        bitBuffer |= (bit ? 1 : 0) << (7 - bitBufferPos);
        if (bitBufferPos == 0)
            data.swrite!ubyte(bitBuffer);
        else
            data.data[data.data.length-1] = bitBuffer;
        
        ++bitBufferPos;

        if (bitBufferPos > 7)
            flushBits();
    }

    void flush() {data.flush();}
    void finalize() {data.finalize();}
    void write(InputStream stream, ulong nbytes = 0, bool do_flush = true) { writeDefault(stream, nbytes, do_flush); }
}

unittest {
    import util.test;
    test!("MemoryOutputBitStream");
    MemoryOutputBitStream stream = new MemoryOutputBitStream();

    stream.writeBit(false);
    stream.writeBit(true);
    stream.swrite!byte(6);
    stream.writeBit(true);
    stream.writeBit(false);
    stream.writeBit(true);
    stream.swrite!byte(20);
    stream.writeBit(true);
    stream.writeBit(true);
    stream.writeBit(false);
    stream.writeBit(true);
    stream.writeBit(true);
    stream.writeBit(true);
    stream.writeBit(false);
    stream.writeBit(false);
    stream.writeBit(false);
    test!("InputBitStreamWrapper");
    ubyte[] data = stream.getData;
    auto istream = new InputBitStreamWrapper(new MemoryStream(data, false));

    
    assert(istream.readBit == false);
    assert(istream.readBit == true);
    assert(istream.sread!byte == 6);
    assert(istream.readBit == true);
    assert(istream.readBit == false);
    assert(istream.readBit == true);
    assert(istream.sread!byte == 20);
    assert(istream.readBit == true);
    assert(istream.readBit == true);
    assert(istream.readBit == false);
    assert(istream.readBit == true);
    assert(istream.readBit == true);
    assert(istream.readBit == true);
    assert(istream.readBit == false);
    assert(istream.readBit == false);
}