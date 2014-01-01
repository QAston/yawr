module util.crypto.hmac_digest;

/++
+ this module is a wrapper around deimos openssl implementation of hmac using sha1 hash
+ ALMOST conforms to phobos digest API - sadly it has to be initialized with key and phobos doesn't allow that
+/

import deimos.openssl.hmac;
import deimos.openssl.sha;

import util.binary;

public import util.crypto.keyed_digest;

struct HMAC
{
public:
    ~this()
    {
        HMAC_CTX_cleanup(&_ctx);
    }

    /// initializes or reinitializes hmac digest
    @trusted nothrow void start(const(ubyte)[] key)
    {
        if (!_init)
        {
            _init = true;
            HMAC_CTX_init(&_ctx);
        }
        if (!HMAC_Init_ex(&_ctx, key.ptr, key.length, EVP_sha1(), null))
            assert(0);
    }

    /// adds new data to digest
    @trusted nothrow void put(scope const(ubyte)[] data...)
    {
        assert(_init);
        if (!HMAC_Update(&_ctx, data.ptr, data.length))
            assert(0);
    }

    /// returns hash of data processed so far
    @trusted nothrow ubyte[SHA_DIGEST_LENGTH] finish()
    {
        assert(_init);
        uint length = 0;
        ubyte[SHA_DIGEST_LENGTH] digest;
        if (!HMAC_Final(&_ctx, digest.ptr, &length))
            assert(0);
        assert (length == SHA_DIGEST_LENGTH);
        return digest;
    }
private:
    HMAC_CTX _ctx;
    bool _init = false;
}

unittest {
    assert(keyedDigest!HMAC("", "") == bin!x"fbdb1d1b18aa6c08324b7d64b71fb76370690e1d");
    assert(keyedDigest!HMAC("key", "The quick brown fox jumps over the lazy dog") == bin!x"de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9");
}