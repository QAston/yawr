/++
+ This module provides interface similar to std.digest.digest for keyed digest.

+/
module util.crypto.keyed_digest;

import std.typetuple : allSatisfy;
import std.traits;
import std.range;
import std.digest.digest;

/// shortcut for creating Hash structs
Hash makeKeyedDigest(Hash, Key)(Key key) if (isArray!(typeof(key)) && isKeyedDigest!Hash)
{
    Hash hash;
    hash.start(cast(const(ubyte[]))key);
    return hash;
}

/// shortcut for calculating digests
KeyedDigestType!Hash keyedDigest(Hash, Key, T...)(Key key, scope const T data) if(allSatisfy!(isArray, typeof(data)) && isArray!(typeof(key)))
{
    Hash hash;
    hash.start(cast(const(ubyte[]))key);
    foreach(datum; data)
        hash.put(cast(const(ubyte[]))datum);
    return hash.finish();
}

/++
+ Evals to type of the keyed digest T
+/
template KeyedDigestType(T)
{
    static if(isKeyedDigest!T)
    {
        alias ReturnType!(typeof(
                                 {
                                     T dig = void;
                                     return dig.finish();
                                 })) KeyedDigestType;
    }
    else
        static assert(false, T.stringof ~ " is not a digest! (fails isKeyedDigest!T)");
}

/++
+ Pred, true if T is a valid keyed digest
+/
template isKeyedDigest(T)
{
    enum bool isKeyedDigest = isOutputRange!(T, const(ubyte)[]) && isOutputRange!(T, ubyte) &&
        is(T == struct) &&
            is(typeof(
                      {
                          T dig = void; //Can define
                          dig.start([0u]);
                          dig.put(cast(ubyte)0, cast(ubyte)0); //varags
                          auto value = dig.finish(); //has finish
                      }));
}

interface Digest
{
public:
    /**
    * Use this to feed the digest with data.
    * Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and
    * $(D const(ubyte)[]).
    *
    * Examples:
    * ----
    * void test(Digest dig)
    * {
    *     dig.put(cast(ubyte)0); //single ubyte
    *     dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
    *     ubyte[10] buf;
    *     dig.put(buf); //buffer
    * }
    * ----
    */
    @trusted nothrow void put(scope const(ubyte)[] data...);

    /**
    * Resets the internal state of the digest.
    * Note:
    * $(LREF finish) calls this internally, so it's not necessary to call
    * $(D reset) manually after a call to $(LREF finish).
    */
    @trusted nothrow void reset();

    /**
    * This is the length in bytes of the hash value which is returned by $(LREF finish).
    * It's also the required size of a buffer passed to $(LREF finish).
    */
    @trusted nothrow @property size_t length() const;

    /**
    * The finish function returns the hash value. It takes an optional buffer to copy the data
    * into. If a buffer is passed, it must be at least $(LREF length) bytes big.
    */
    @trusted nothrow ubyte[] finish();
    ///ditto
    nothrow ubyte[] finish(scope ubyte[] buf);
    //@@@BUG@@@ http://d.puremagic.com/issues/show_bug.cgi?id=6549
    /*in
    {
    assert(buf.length >= this.length);
    }*/

    /**
    * This is a convenience function to calculate the hash of a value using the OOP API.
    *
    * Examples:
    * ---------
    * import std.digest.md, std.digest.sha, std.digest.crc;
    * ubyte[] md5   = (new MD5Digest()).digest("The quick brown fox jumps over the lazy dog");
    * ubyte[] sha1  = (new SHA1Digest()).digest("The quick brown fox jumps over the lazy dog");
    * ubyte[] crc32 = (new CRC32Digest()).digest("The quick brown fox jumps over the lazy dog");
    * assert(crcHexString(crc32) == "414FA339");
    * ---------
    *
    * ---------
    * //It's also possible to pass multiple values to this function:
    * import std.digest.crc;
    * ubyte[] crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
    * assert(crcHexString(crc32) == "414FA339");
    * ---------
    */
    final @trusted nothrow ubyte[] digest(scope const(void[])[] data...)
    {
        this.reset();
        foreach(datum; data)
            this.put(cast(ubyte[])datum);
        return this.finish();
    }
}