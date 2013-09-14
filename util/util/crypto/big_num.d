module util.crypto.big_num;

import std.typecons;
import std.traits;
import std.system;
import std.algorithm : reverse;
import std.exception;
import std.bigint;

import util.string;
import deimos.openssl.bn;
import deimos.openssl.err;

/++
+ Copy on write BigNumber structure - a dlang friendly interface to deimos.openssl.bn
+ Sadly not immutable-correct due to DMD issues with assignment in constructors :(
+/
struct BigNumber
{
private:
    RefCounted!(bignum_st*) bigNum;
    bool clearOnDestroy;
public:
    /// clearOnDestroy - if true erases data before freeing memory
    this(BigNumber rhs, bool clearOnDestroy = false)
    {
        this(rhs.payload, rhs.clearOnDestroy ? true : clearOnDestroy);
    }

    /// BigNumber equal to given binary representation; clearOnDestroy - if true erases data before freeing memory
    this(in ubyte[] array, Endian endian, bool clearOnDestroy = false)
    {
        if (endian == Endian.littleEndian)
        {
            import std.conv;
            auto a  = array.dup;
            reverse(a);
            this(BN_bin2bn(a.to!(const ubyte[]).ptr, array.length, null), clearOnDestroy);
        }
        else
            this(BN_bin2bn(array.ptr, array.length, null), clearOnDestroy);
    }

    /// takes a string in a HEX format
    this(string s, bool clearOnDestroy = false)
    {
        import std.string;
        auto bn = BN_new();
        BN_hex2bn(&bn, s.toStringz);
        this(bn, clearOnDestroy);
    }

    /// BigNumber equal to given val clearOnDestroy - if true erases data before freeing memory
    this(T)(T val, bool clearOnDestroy = false) if (isIntegral!T)
    {
        auto bn = BN_new();
        set(bn, val);
        this(bn, clearOnDestroy);
    }

    ~this()
    {
        if (bigNum.refCountedStore.refCount() == 1)
        {
            if (clearOnDestroy)
                BN_clear(bigNum.refCountedPayload);
            else
                BN_free(bigNum.refCountedPayload);
        }
    }

    private this(bignum_st* val, bool clearOnDestroy = false)
    {
        assert(val !is null);
        bigNum = val;
        this.clearOnDestroy = clearOnDestroy;
    }

    private inout(bignum_st*) payload() inout
    {
        return bigNum.refCountedPayload;
    }

    private static void set(T)(bignum_st* bn, T val) if (isIntegral!T)
    {
        static if (is (T==ulong) || is (T==long))
        {
            BN_set_word(bn, cast(uint)(val >>> 32));
            BN_lshift(bn, bn, 32);
            static if (is (T==ulong))
            {
                BN_add_word(bn, cast(uint)(val & 0xFFFFFFFF));
            }
            else
            {
                BN_add_word(bn, cast(uint)(val & 0x7FFFFFFF));
                BN_set_negative(bn, val < 0);
            }
        }
        else
        {
            static if (isSigned!T)
            {
                import std.math;
                BN_set_word(bn, abs(val));
                BN_set_negative(bn, val < 0);
            }
            else
                BN_set_word(bn, val);
        }
    }

    private static void enforceArithm(int returnCode)
    {
        if (returnCode == 0)
            throw new BigNumberException(ERR_peek_last_error());
    }

    private static void enforcePositive(const BigNumber num)
    {
        if (BN_is_negative(num.payload))
        {
            throw new BigNumberException("Negative number passed to function expecting positive");
        }
    }

    private static bignum_st* allocBN()
    {
        auto ptr = BN_new();
        if (ptr is null)
            throw new BigNumberException(ERR_peek_last_error());
        return ptr;
    }

    private static BN_CTX* allocBN_CTX()
    {
        auto ptr = BN_CTX_new();
        if (ptr is null)
            throw new BigNumberException(ERR_peek_last_error());
        return ptr;
    }

    ///
    bool isPositive() const
    {
        return !BN_is_negative(payload);
    }

    ///
    bool isNegative() const
    {
        return BN_is_negative(payload);
    }

    bool isZero() const
    {
        return BN_is_zero(payload);
    }

    ///
    size_t toHash() const
    {
        // todo: make better hash?
        return BN_get_word(payload);
    }

    ///
    bool opEquals(in BigNumber bn) const
    {
        return BN_cmp(payload, bn.payload) == 0;
    }

    ///
    bool opEquals(T)(in T bn) const if (isIntegral!T)
    {
        return this.opEquals(BigNumber(bn));
    }

    ///
    int opCmp(in BigNumber bn) const
    {
        return BN_cmp(payload, bn.payload);
    }

    ///
    int opCmp(T)(in T bn) const if (isIntegral!T)
    {
        return this.opCmp(BigNumber(bn));
    }

    ///
    BigNumber opBinary(string op, T)(in T val) const if (isIntegral!T)
    {
        return opBinary!op(BigNumber(val));
    }

    ///
    BigNumber opBinaryRight(string op, T)(in T val) const if (isIntegral!T)
    {
        return BigNumber(val).opBinary!op(this);
    }

    ///
    BigNumber opBinary(string op:"+")(in BigNumber bn) const
    {
        auto ret = allocBN();
        enforceArithm(BN_add(ret, payload, bn.payload));
        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"-")(in BigNumber bn) const
    {
        auto ret = allocBN();
        enforceArithm(BN_sub(ret, payload, bn.payload));
        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"*")(in BigNumber bn) const
    {
        BN_CTX *bnctx;
        auto ret = allocBN();

        bnctx = allocBN_CTX();
        enforceArithm(BN_mul(ret, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"/")(in BigNumber bn) const
    {
        BN_CTX *bnctx;
        auto ret = allocBN();

        bnctx = allocBN_CTX();
        enforceArithm(BN_div(ret, null, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"%")(in BigNumber bn) const
    {
        BN_CTX *bnctx;
        auto ret = allocBN();

        bnctx = allocBN_CTX();
        enforceArithm(BN_mod(ret, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"^^")(in BigNumber bn) const
    {
        auto ret = allocBN();
        BN_CTX *bnctx;

        bnctx = allocBN_CTX();
        enforceArithm(BN_exp(ret, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    /// Raises number to given power and calcs given modulus at the same time
    BigNumber modExp(in BigNumber power, in BigNumber modulus) const
    {
        auto ret = allocBN();
        BN_CTX *bnctx;

        bnctx = allocBN_CTX();
        enforceArithm(BN_mod_exp(ret, payload, power.payload, modulus.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, power.clearOnDestroy);
    }

    /// Returns length of a byte array with binary representation of the number
    size_t byteArrayLength() const
    {
        enforcePositive(this);
        return BN_num_bytes(payload);
    }

    ///
    uint opCast(T:uint)() const
    {
        enforcePositive(this);
        return BN_get_word(payload);
    }

    /// Returns a string of hexadecimal numbers
    string toHexString() const
    {
        return cast(string)stringzToString(BN_bn2hex(payload));
    }

    ///
    string toString() const
    {
        return cast(string)stringzToString(BN_bn2dec(payload));
    }

    /// Converts BigNumber to array of bytes with given endianess and min array size if specified
    ubyte[] toByteArray(Endian endianess, size_t minSize = size_t.max) const
    {
        enforcePositive(this);
        int length;
        if (minSize == size_t.max)
            length = byteArrayLength();
        else
            length = (minSize >= byteArrayLength()) ? minSize : byteArrayLength();

        auto array = new ubyte[length];

        BN_bn2bin(payload, array.ptr);

        if (endianess == Endian.littleEndian)
            reverse(array);

        return array;
    }
}

/++
+ Returns a random BigNumber which has given number of bits
+/
BigNumber random(size_t numbits, bool clearOnDestroy = false)
{
    auto ret = BigNumber.allocBN();
    if (BN_rand(ret, numbits, 0, 1) == 0)
        throw new BigNumberException(ERR_peek_last_error());
    return BigNumber(ret, clearOnDestroy);
}

/// thrown on failure of any BigNumber operation
class BigNumberException : Exception
{
    this(uint errCode, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        auto buf = new char[120];
        ERR_error_string_n(errCode, buf.ptr, buf.length);
        super("BigNumber Error: " ~ assumeUnique(stringzToString(buf.ptr)), file, line, next);
    }
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

unittest {
    import util.test;
    mixin(test!("BigNum"));
    bool arithmTest(string op)(ulong a1, ulong a2)
    {
        auto t1 = BigNumber(a1);
        auto t2 = BigNumber(a2);
        mixin ("return (t1 " ~ op ~ " t2 == BigNumber(a1 " ~op~ " a2));");
    }
    
    assert(arithmTest!"+"(5, 234));
    assert(arithmTest!"-"(234, 5));
    assert(arithmTest!"*"(234, 5));
    assert(arithmTest!"/"(234, 5));
    assert(arithmTest!"%"(234, 5));
    assert(arithmTest!"^^"(234, 5));
    auto t3 = BigNumber(56u);
    auto t4 = BigNumber(t3);
    assert(t3==t4);
    assert(t3.toHash() == t4.toHash());
    assert(t3.byteArrayLength == 1);
    BigNumber t6 =70;
    assert(t3==BigNumber(56));
    assert(t6 == BigNumber(70u));
    assert(t6 > t3);
    assert(t6 >= t3);
    assert(t3 < t6);
    assert(t3==t3);
    assert(t3 <= t6);
    auto t5 = random(2);
    assert(t5 < BigNumber(4u));
    assert(t5.toString() !is null);
    assert(t3.isPositive);
    assert(!t3.isNegative);
    ubyte ut6 = 70;
    import util.binary;
    auto bt6 = asByteArray(ut6);
    assert(t6.toByteArray(Endian.littleEndian) == bt6);
    import std.conv;
    assert(ut6.to!string == t6.to!string);
    auto t7 = t6 - 10u;
    assert(t7 == 60);
    assert(t7 == 60u);
    assert(t7.toString == "60");
    assert(t7.toHexString == "3C");
    assert(t7 > 59u);
    assert(t7 < 61);
}