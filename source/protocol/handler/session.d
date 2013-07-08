module protocol.handler.session;

import protocol.opcode;
import protocol.version_;

alias ushort ClientBuild;

struct AuthSession {
    byte[20] sha;
    ClientBuild build;
    string accountName;
    uint clientSeed;
    //ClientAddonsList!(true) clientAddonsList;

    template as(T)
    {
        import vibe.core.stream;
        import protocol.stream_utils;

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
        import protocol.stream_utils;

        static void write(VAL)(OutputStream str, ref VAL val)
        {
            str.swrite!VAL(val);
        }
        static VAL read(VAL)(InputStream str)
        {
            return str.sread!VAL();
        }
    }
    /+
     + Behavior depends on whenever in read or write mode
     + Read: Copies data from stream to value
     + Write: Copies thata from value to stream
     + Parameters:
     + Format - template functions which handles read/write to stream
     +/
    void val(alias Format = identity, T)(ref T value)
    {
        value = Format.read!T(null);
        //         Format.write(null, value);
    }

    /+
     + Behavior depends on whenever in read or write mode
     + Read: Copies data from stream to value's length property
     + Write: Copies thata from value's length property to stream
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

    void handle()
    {
        skip!uint;
        skip!uint;
        skip!byte;
        val(sha[10]);
        val(sha[18]);
        val(sha[12]);
        val(sha[5]);
        skip!ulong;
        val(sha[15]);
        val(sha[9]);
        val(sha[19]);
        val(sha[4]);
        val(sha[7]);
        val(sha[16]);
        val(sha[3]);
        val!(as!ushort)(build);
        val(sha[8]);
        skip!uint;
        skip!byte;
        val(sha[17]);
        val(sha[6]);
        val(sha[0]);
        val(sha[1]);
        val(sha[11]);
        val!(as!ushort)(clientSeed);
        val(sha[2]);
        skip!uint;
        val(sha[14]);
        val(sha[13]);

       // clientAddonsList.val;

        skip!byte;

        //accountName.valCount(asBits(12));
        //accountName.val;
    }
}

struct Addon {
    // cstring
    string name;
    bool enabled;
    int crc;
    // unknown field
    //uint unknown;
}
/*
alias uint Time;
struct ClientAddonsList(bool valDeflatedSize) {
    Addon[] addons;

    Time time;

    void handle()
    {
        // options: deflate stream, write deflated size
        deflatedBlock!(true, valDeflatedSize)((){
            static if (protocolVersion >= V3_0_8_9464)
            {
                addons.valCount;

                addons.valArray((Addon a) {
                    a.name.val(asCstring);
                    a.enabled.val;
                    a.crc.val;
                    skip!int;
                }, asRemainingData());

                time.val;
            }
            else
            {
                addons.valArray((Addon a) {
                    a.name.val(asCstring);
                    a.enabled.val;
                    a.crc.val;
                    skip!int;
                }, asRemainingData());
            }
        });
    }
}*/