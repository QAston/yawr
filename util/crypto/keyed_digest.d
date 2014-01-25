/++
+ This module provides interface similar to std.digest.digest for keyed digest.
+/
module util.crypto.keyed_digest;

import std.typetuple : allSatisfy;
import std.traits;
import std.range;


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