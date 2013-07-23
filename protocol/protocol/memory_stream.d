module protocol.memory_stream;

import vibe.stream.memory;
import util.stream;

class BitMemoryStream {
    private {
        MemoryStream data;
        // buffer for streaming in bits
        ubyte bitBuffer;
        ubyte bitBufferPos;
    }
    void flushBits()
    {
        bitBuffer = 0;
        bitBufferPos = 0;
    }
    this(ubyte[] data, bool writable = true, size_t initial_size = size_t.max)
    {
        this.data = new MemoryStream(data, writable, initial_size);
    }
    void write(in ubyte[] bytes, bool do_flush = true)
    {
        flushBits();
        data.write(bytes, do_flush);
    }
    void read(ubyte[] dst)
    {
        flushBits();
        data.read(dst);
    }
    void seek(ulong offset)
    {
        flushBits();
        data.seek(offset);
    }
    bool readBit()
    {
        if (bitBufferPos == 0)
            bitBuffer = data.sread!ubyte;

        auto val = ((bitBuffer >>> (7 - bitBufferPos++)) & 1) != 0;
        if (bitBufferPos == 8)
            flushBits();
        return val;
    }
    
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

	@property bool empty() { return data.empty(); }
	@property ulong leastSize() { return data.leastSize(); }
	@property bool dataAvailableForRead() { return data.dataAvailableForRead; }
	@property ulong size() const nothrow { return data.size(); }
	@property size_t capacity() const nothrow { return data.capacity(); }
	@property bool readable() const nothrow { return data.readable(); }
	@property bool writable() const nothrow { return data.writable(); }
    ulong tell() nothrow { return data.tell(); }
}

public string toHex(STREAM)(STREAM data)
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