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
+/
struct BigNumber
{
private:
    RefCounted!(bignum_st*) bigNum;
    bool clearOnDestroy;
public:
    invariant()
    {
        assert(bigNum.refCountedPayload !is null);
    }

    /// clearOnDestroy - if true erases data before freeing memory
    this(BigNumber rhs, bool clearOnDestroy = false)
    {
        bigNum = RefCounted!(bignum_st*)(rhs.payload);
        if (rhs.clearOnDestroy)
            clearOnDestroy = rhs.clearOnDestroy;
    }

    /// BigNumber equal to given binary representation; clearOnDestroy - if true erases data before freeing memory
    this(ubyte[] array, Endian endian, bool clearOnDestroy = false)
    {
        if (endian == Endian.littleEndian)
            reverse(array);
        this(BN_bin2bn(array.ptr, array.length, null), clearOnDestroy);
    }

    /// BigNumber equal to given val clearOnDestroy - if true erases data before freeing memory
    this(T)(T val, bool clearOnDestroy = false) if (isIntegral!T)
    {
        auto bn = BN_new();
        set(bn, val);
        bigNum = bn;
        this.clearOnDestroy = clearOnDestroy;
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

    private static void enforcePositive(BigNumber num)
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
    bool isPositive()
    {
        return !BN_is_negative(payload);
    }

    ///
    bool isNegative()
    {
        return BN_is_negative(payload);
    }

    ///
    void setNegative(bool neg)
    {
        BN_set_negative(payload, neg ? 1 : 0);
    }

    ///
    size_t toHash() const
    {
        // todo: make better hash?
        return BN_get_word(payload);
    }

    ///
    bool opEquals(BigNumber bn) const
    {
        return BN_cmp(payload, bn.payload) == 0;
    }

    ///
    bool opEquals(T)(T bn) const if (isIntegral!T)
    {
        return this.opEquals(BigNumber(bn));
    }

    ///
    int opCmp(BigNumber bn) const
    {
        return BN_cmp(payload, bn.payload);
    }

    ///
    int opCmp(T)(T bn) const if (isIntegral!T)
    {
        return this.opCmp(BigNumber(bn));
    }

    ///
    BigNumber opAssign(T)(T val) if (isIntegral!T)
    {
        auto bn = allocBN();
        set(bn, val);
        clearOnDestroy = false;
        bigNum = bn;
        return this;
    }

    ///
    BigNumber opAssign(T:BigNumber)(T x)
    {
        bigNum = x.payload;
        clearOnDestroy = x.clearOnDestroy;
        return this;
    }

    BigNumber opOpAssign(string op, T)(T x)
    {
        this = this.opBinary!op(x);
        return this;
    }

    ///
    BigNumber opBinary(string op, T)(T val) const if (isIntegral!T)
    {
        return opBinary!op(BigNumber(val));
    }

    ///
    BigNumber opBinaryRight(string op, T)(T val) const if (isIntegral!T)
    {
        return BigNumber(val).opBinary!op(this);
    }

    ///
    BigNumber opBinary(string op:"+")(BigNumber bn) const
    {
        auto ret = allocBN();
        enforceArithm(BN_add(ret, payload, bn.payload));
        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"-")(BigNumber bn) const
    {
        auto ret = allocBN();
        enforceArithm(BN_sub(ret, payload, bn.payload));
        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"*")(BigNumber bn) const
    {
        BN_CTX *bnctx;
        auto ret = allocBN();

        bnctx = allocBN_CTX();
        enforceArithm(BN_mul(ret, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"/")(BigNumber bn) const
    {
        BN_CTX *bnctx;
        auto ret = allocBN();

        bnctx = allocBN_CTX();
        enforceArithm(BN_div(ret, null, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"%")(BigNumber bn) const
    {
        BN_CTX *bnctx;
        auto ret = allocBN();

        bnctx = allocBN_CTX();
        enforceArithm(BN_mod(ret, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    ///
    BigNumber opBinary(string op:"^^")(BigNumber bn) const
    {
        auto ret = allocBN();
        BN_CTX *bnctx;

        bnctx = allocBN_CTX();
        enforceArithm(BN_exp(ret, payload, bn.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, bn.clearOnDestroy);
    }

    /// Raises number to given power and calcs given modulus at the same time
    BigNumber modExp(BigNumber power, BigNumber modulus) const
    {
        auto ret = allocBN();
        BN_CTX *bnctx;

        bnctx = allocBN_CTX();
        enforceArithm(BN_mod_exp(ret, payload, power.payload, modulus.payload, bnctx));
        BN_CTX_free(bnctx);

        return BigNumber(ret, power.clearOnDestroy);
    }

    /// Returns length of a byte array with binary representation of the number
    size_t byteArrayLength()
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
    ubyte[] toByteArray(Endian endianess, size_t minSize = size_t.max)
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
    t4 =70;
    assert(t3==BigNumber(56));
    assert(t4 == BigNumber(70u));
    assert(t4 > t3);
    assert(t4 >= t3);
    assert(t3 < t4);
    assert(t3==t3);
    assert(t3 <= t4);
    auto t5 = random(2);
    assert(t5 < BigNumber(4u));
    assert(t5.toString() !is null);
    assert(t3.isPositive);
    assert(!t3.isNegative);
    ubyte ut4 = 70;
    import util.bit;
    auto bt4 = asByteArray(ut4);
    assert(t4.toByteArray(Endian.littleEndian) == bt4);
    import std.conv;
    assert(ut4.to!string == t4.to!string);
    t4 -= 10u;
    assert(t4 == 60);
    assert(t4 == 60u);
    assert(t4.toString == "60");
    assert(t4.toHexString == "3C");
    assert(t4 > 59u);
    assert(t4 < 61);
    t4.setNegative(true);
    assert(t4==-60);
    assert(t4.isNegative);
}