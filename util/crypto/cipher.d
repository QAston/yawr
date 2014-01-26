module util.crypto.cipher;

import util.typecons : emptyArray;

interface Cipher
{
    ubyte[] update(const(ubyte)[] data);
    ubyte[] finish();
}

class NullCipher : Cipher
{
    ubyte[] update(const(ubyte)[] data)
    {
        return data.dup;
    }
    ubyte[] finish()
    {
        return emptyArray!ubyte();
    }
}

unittest {
    import std.range;
    ubyte[] a = [ 1, 2, 3 ];
    auto cipher = new NullCipher();
    assert(a == cipher.update(a));
}
