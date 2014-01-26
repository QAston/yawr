module util.crypto.arc4;

/++
+ this module is a wrapper around deimos openssl implementation of arc4
+/

import deimos.openssl.evp;
import std.range;

struct ARC4
{
public:
    @disable this();

    /// initializes arc4 with given seed
    this(const(ubyte)[] seed)
    {
        _ctx = EVP_CIPHER_CTX_new();
        if (_ctx is null)
            throw new Exception("Could not create EVP_CIPHER_CTX");
        EVP_CIPHER_CTX_init(_ctx);
        if (!EVP_EncryptInit_ex(_ctx, EVP_rc4(), null, null, null))
            assert(0);
        if (!EVP_CIPHER_CTX_set_key_length(_ctx, seed.length))
            assert(0);
        if (!EVP_EncryptInit_ex(_ctx, null, null, seed.ptr, null))
            assert(0);
    }

    ~this()
    {
        if (!EVP_CIPHER_CTX_cleanup(_ctx))
            assert(0);
        EVP_CIPHER_CTX_free(_ctx);
    }

    /// returns encrypted data blocks, size of data returned is aligned to EVP_CIPHER_CTX_block_size, data which didn't fit into the block will be returned with next calls
    ubyte[] update(const(ubyte)[] data)
    {
        ubyte[] ret = new ubyte[EVP_CIPHER_CTX_block_size(_ctx) + data.length - 1];
        int outlen = 0;
        if (!EVP_EncryptUpdate(_ctx, ret.ptr, &outlen, data.ptr, data.length))
            assert(0);
        return ret[0..outlen];
    }

    /// encrypts remaining data unaligned to EVP_CIPHER_CTX_block_size
    ubyte[] finish()
    {
        int outlen = 0;
        ubyte[] ret = new ubyte[EVP_CIPHER_CTX_block_size(_ctx)];
        if (!EVP_EncryptFinal_ex(_ctx, ret.ptr, &outlen))
            assert(0);
        return ret[0..outlen];
    }
private:
    EVP_CIPHER_CTX* _ctx;
}

unittest {
    import util.test;
    import util.binary;
    mixin(test!("arc4"));
    // test vectors are taken from wikipedia
    {
        ARC4 arc4 = ARC4(cast(ubyte[])"Key");
        assert((arc4.update(cast(ubyte[])"Plaintext") ~ arc4.finish()) == bin!x"BBF316E8D940AF0AD3");
    }
    {
        ARC4 arc4 = ARC4(cast(ubyte[])"Wiki");
        assert((arc4.update(cast(ubyte[])"pedia") ~ arc4.finish()) == bin!x"1021BF0420");
    }
    {
        ARC4 arc4 = ARC4(cast(ubyte[])"Secret");
        assert((arc4.update(cast(ubyte[])"Attack at dawn") ~ arc4.finish()) == bin!x"45A01F645FC35B383552544B9BF5");
    }
}

public import util.crypto.cipher;

class ARC4Cipher : Cipher {
    private ARC4 _cipher;

    this(const(ubyte)[] seed)
    {
        _cipher = ARC4(seed);
    }

    ubyte[] update(const(ubyte)[] data)
    {
        return _cipher.update(data);
    }

    ubyte[] finish()
    {
        return _cipher.finish();
    }
}