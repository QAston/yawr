module protocol.packet;

import vibe.stream.memory;

import protocol.opcode;
import std.array;

class Packet(bool input)
{
    enum isInput = input;
    enum isOutput = !input;

    MemoryStream data;
    Opcode opcode;
    this(ubyte[] data, uint opcode)
    {
        this.data = new MemoryStream(data);
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

        import util.stream;
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
    void val(alias Format = identity, T)(ref T value)
    {
        if (isInput)
            value = Format.read!T(data);
        else
            Format.write(data, value);
    }
    
    /+
     + Behavior depends on whenever in input or output mode
     + input: Copies data from stream to value's length property
     + output: Copies value's length property from value to stream
     + Parameters:
     + Format - template functions which handles read/write to stream
     +/
    void valCount(alias Format = identity, T)(ref T value)
    {
        
    }
    
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

struct Handler(Opcode op)
{
    enum opcode = op;
}

// packet read/write primitives
template as(T)
{
    import vibe.core.stream;
    import util.stream;
    
    alias T returnedType;
    void write(VAL)(OutputStream str, ref VAL val)
    {
        str.swrite!T(cast(T)val);
    }
    T read(VAL)(InputStream str)
    {
        return cast(VAL)str.sread!T();
    }
}

static struct identity
{
    import vibe.core.stream;
    import util.stream;
    
    static void write(VAL)(OutputStream str, ref VAL val)
    {
        str.swrite!VAL(val);
    }
    static VAL read(VAL)(InputStream str)
    {
        return str.sread!VAL();
    }
}
